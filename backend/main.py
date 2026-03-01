import os
from typing import Optional, List
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from langchain_community.chat_message_histories import ChatMessageHistory
from langchain_core.chat_history import BaseChatMessageHistory
from langchain_core.runnables.history import RunnableWithMessageHistory
from dotenv import load_dotenv
from supabase import create_client, Client
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain.agents import AgentExecutor, create_react_agent
from langchain.tools import tool, StructuredTool
from langchain.tools.render import render_text_description
import logging
from langchain_core.prompts import PromptTemplate

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("PharmaCo")

# --- MEMORY STORE ---
store = {}

class SanitizedChatMessageHistory(ChatMessageHistory):
    def add_message(self, message):
        # Sanitize tool calls to fix the 'fun...ion' truncation bug
        if hasattr(message, 'tool_calls') and message.tool_calls:
            for tc in message.tool_calls:
                if isinstance(tc, dict) and tc.get('type') != 'function':
                    tc['type'] = 'function'
                elif hasattr(tc, 'type') and tc.type != 'function':
                    tc.type = 'function'
        super().add_message(message)

def get_session_history(session_id: str) -> BaseChatMessageHistory:
    if session_id not in store:
        store[session_id] = SanitizedChatMessageHistory()
    
    # Proactively fix any mangled tool calls in existing history
    history = store[session_id]
    for msg in history.messages:
        if hasattr(msg, 'tool_calls') and msg.tool_calls:
            for tc in msg.tool_calls:
                # Handle both dict and object types that LangChain uses
                if isinstance(tc, dict):
                    if tc.get('type') != 'function':
                        tc['type'] = 'function'
                elif hasattr(tc, 'type'):
                    if tc.type != 'function':
                        tc.type = 'function'
                # Also check nested dicts if they exist
                if isinstance(tc, dict) and 'function' in tc and isinstance(tc['function'], dict):
                    pass # Standard structure
    return history

# ------------------ LOAD ENV ------------------
load_dotenv(override=True)

# Enable LangSmith tracing (Set after load_dotenv to ensure keys are loaded)
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_API_KEY"] = os.getenv("LANGCHAIN_API_KEY", "")
os.environ["LANGCHAIN_PROJECT"] = os.getenv("LANGCHAIN_PROJECT", "PharmaCo")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
PRESCRIPTO_API_KEY = os.getenv("PRESCRIPTO_API_KEY")

# Create a service role client to bypass RLS for system operations
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# ------------------ FASTAPI ------------------
app = FastAPI(title="PharmaCo AI Server")

# Add CORS middleware to allow requests from the Flutter frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"message": "PharmaCo backend running 🚀"}

# ------------------ AI MODEL ------------------
# ------------------ AI MODEL ------------------
# Switched back to standard ChatOpenAI since ReAct agent doesn't need
# the complex tool-call sanitization that was failing.
llm = ChatOpenAI(
    model="openai/gpt-4o-mini",
    temperature=0,
    max_tokens=600,
    api_key=OPENAI_API_KEY,
    base_url="https://openrouter.ai/api/v1",
    default_headers={
        "HTTP-Referer": "https://github.com/shahid9890/Pharmoco-user",
        "X-Title": "PharmaCo"
    }
)

# ------------------ TOOLS ------------------

@tool
def check_medicine_inventory(input_str: str) -> str:
    """Check the user's personal medicine inventory/cabinet.
    Input MUST be a JSON string: {"user_id": "...", "medicine_name": "..."}
    To see EVERYTHING in their inventory, use "medicine_name": "all".
    """
    import json
    try:
        # Robust parsing
        data = {}
        try:
            start = input_str.find('{')
            end = input_str.rfind('}')
            if start != -1 and end != -1:
                data = json.loads(input_str[start:end+1])
            else:
                data = json.loads(input_str)
        except:
            # Fallback for raw string if it looks like a UUID
            if len(input_str.strip()) > 30:
                 data = {"user_id": input_str.strip(), "medicine_name": "all"}
            else:
                return "Error: Input must be a JSON object with user_id and medicine_name."

        user_id = data.get("user_id")
        medicine_name = data.get("medicine_name", "all")
        
        if not user_id:
            return "Error: user_id is required."

        query = supabase_admin.table("user_inventory").select("*").eq("user_id", user_id)
        
        # If not "all", filter by name
        if medicine_name.lower() != "all" and medicine_name.strip() != "":
            query = query.ilike("medicine_name", f"%{medicine_name}%")
            
        inventory = query.execute()
        
        logger.info(f"Inventory Check: user={user_id}, query={medicine_name}, found={len(inventory.data) if inventory.data else 0}")

        if not inventory.data:
            if medicine_name.lower() == "all":
                return "Your personal inventory is currently empty."
            return f"No {medicine_name} found in your personal inventory."
        
        results = []
        for item in inventory.data:
            expiry = item.get('expiry_date', 'Not set')
            daily = item.get('daily_usage', 'Not set')
            results.append(f"- {item.get('medicine_name')}: {item.get('quantity')} units (Daily Use: {daily}, Expiry: {expiry})")
            
        header = "Your Personal Inventory:\n" if medicine_name.lower() == "all" else f"Inventory matches for '{medicine_name}':\n"
        return header + "\n".join(results)
    except Exception as e:
        logger.error(f"Inventory Tool Error: {e}")
        return f"Error checking inventory: {str(e)}"

@tool
def get_medicine_details(medicine_name: str) -> str:
    """Get price and prescription requirement for a medicine.
    Input should be the medicine name.
    """
    try:
        # Search in primary_medicines or medicines table to get the best price
        med_res = supabase_admin.rpc("search_medicines", {"search_term": medicine_name}).execute()
        
        if not med_res.data:
            return f"Medicine '{medicine_name}' not found in our database."
        
        # Sort by price descending to show the "higher price" as requested
        sorted_meds = sorted(med_res.data, key=lambda x: x.get('price', 0), reverse=True)
        best_match = sorted_meds[0]
        
        req_str = "REQUIRED" if best_match.get('prescription_required') else "NOT REQUIRED"
        
        return (
            f"--- MEDICINE DETAILS ---\n"
            f"Name: {best_match.get('name')}\n"
            f"Price: ₹{best_match.get('price')}\n"
            f"Prescription: {req_str}\n"
            f"Medicine ID: {best_match.get('id')}\n"
            f"------------------------"
        )
    except Exception as e:
        return f"Error fetching medicine details: {str(e)}"


def clean_input_string(input_str: str, key: str = "user_id") -> str:
    """Robustly extracts a value from a potentially messy agent input string."""
    import re, json
    curr_str = input_str.strip()
    # Try to find a UUID pattern first if we're looking for an ID
    if key == "user_id":
        match = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', curr_str, re.I)
        if match: return match.group(0)
    
    # Try parsing as JSON
    try:
        # Extract everything between the first { and last }
        start = curr_str.find('{')
        end = curr_str.rfind('}')
        if start != -1 and end != -1:
            json_blob = curr_str[start:end+1]
            data = json.loads(json_blob)
            return str(data.get(key, curr_str))
    except:
        pass
        
    # Final fallback: strip common artifacts
    return curr_str.strip("'\" {}[]").split(":")[-1].strip().strip("'\"")

@tool
def get_user_profile(user_id: str) -> str:
    """Get user's profile summary (allergies, address, wallet).
    Argument: user_id (string UUID)
    """
    try:
        user_id = clean_input_string(user_id, "user_id")
        profile = supabase_admin.table("user_profiles").select("*").eq("id", user_id).single().execute()
        if profile.data:
            p = profile.data
            allergies = p.get('allergies', [])
            allergies_str = ", ".join(allergies) if isinstance(allergies, list) else str(allergies)
            chronic = p.get('chronic_conditions', [])
            chronic_str = ", ".join(chronic) if isinstance(chronic, list) else str(chronic)
            meds = p.get('regular_medications', [])
            meds = ", ".join(meds) if isinstance(meds, list) else str(meds)
            profile_str = (
                f"--- User Profile Summary ---\n"
                f"Name: {p.get('full_name', 'Not set')}\n"
                f"Age: {p.get('age', 'Not set')}\n"
                f"Gender: {p.get('gender', 'Not set')}\n"
                f"Address: {p.get('address', 'Not set')}\n"
                f"Blood Group: {p.get('blood_group', 'Not set')}\n"
                f"Weight: {p.get('weight', 'Not set')} kg\n"
                f"Height: {p.get('height', 'Not set')} cm\n"
                f"Allergies: {allergies_str if allergies_str else 'None reported'}\n"
                f"Chronic Conditions: {chronic_str if chronic_str else 'None reported'}\n"
                f"Regular Medications: {meds}\n"
                f"Wallet Balance: ₹{p.get('wallet_balance', 0.0)}\n"
                f"Profile Status: {'Complete' if p.get('is_profile_complete') else 'Incomplete'}\n"
                f"--------------------------------"
            )
            return profile_str
        return f"User profile not found for ID: {user_id}"
    except Exception as e:
        return f"Error fetching profile: {str(e)}"

@tool
def suggest_generic_substitutes(medicine_name: str) -> str:
    """Suggest affordable generic alternatives for a branded medicine.
    This should be used when a medicine is out of stock or specifically requested.
    Input should be the branded medicine name.
    """
    try:
        # 1. Try database first
        response = supabase_admin.table("primary_medicines").select("name,brand,description,price").ilike("name", f"%{medicine_name}%").execute()
        
        if response.data and len(response.data) > 0:
            results = []
            for med in response.data:
                results.append(f"Substitute: {med['name']}\nBrand: {med['brand']}\nPrice: ₹{med['price']}\nInfo: {med['description']}")
            return "MATCHES_FOUND: I found these matches in our database which are available for order:\n\n" + "\n\n".join(results)
        
        # 2. LLM Fallback if no database match
        logger.info(f"No DB match for substitute '{medicine_name}'. Using LLM fallback.")
        
        fallback_prompt = f"Suggest 1-2 popular generic salt/alternatives for the branded medicine '{medicine_name}'. For each, provide: 1. Generic Name, 2. Common use, 3. Why it is a good alternative. Keep it professional and concise for a health assistant."
        
        messages = [
            SystemMessage(content="You are a helpful medical assistant specializing in generic medicine substitutes."),
            HumanMessage(content=fallback_prompt)
        ]
        
        ai_res = llm.invoke(messages)
        return f"NO_STORE_MATCH: I couldn't find a direct match in our inventory, but here are some common generic alternatives for {medicine_name} that you can discuss with your doctor (Note: These are NOT currently in our stock):\n\n{ai_res.content}\n\nNote: Please consult a healthcare professional before switching medications."

    except Exception as e:
        logger.error(f"Substitute Tool Error: {e}")
        return f"Error suggesting substitutes: {str(e)}"

@tool
def remove_from_cart(input_str: str) -> str:
    """Remove a specific medicine from the user's shopping cart.
    Input MUST be a JSON string: {"user_id": "...", "medicine_name": "..."}
    """
    import json
    try:
        data = {}
        try:
            start = input_str.find('{')
            end = input_str.rfind('}')
            if start != -1 and end != -1:
                data = json.loads(input_str[start:end+1])
            else:
                data = json.loads(input_str)
        except:
             return "Error: Input must be a JSON object with user_id and medicine_name."

        user_id = data.get("user_id")
        medicine_name = data.get("medicine_name")

        if not user_id or not medicine_name:
            return "Error: user_id and medicine_name are required."

        # 1. Resolve medicine ID
        med_res = supabase_admin.rpc("search_medicines", {"search_term": medicine_name}).execute()
        if not med_res.data:
            return f"Could not find medicine '{medicine_name}' in our database."
        
        medicine = med_res.data[0]
        med_id = medicine['id']

        # 2. Delete from cart
        res = supabase_admin.table("cart").delete().eq("user_id", user_id).eq("medicine_id", med_id).execute()
        
        if res.data:
            return f"Successfully removed '{medicine['name']}' from your cart."
        return f"'{medicine['name']}' was not found in your cart."
    except Exception as e:
        logger.error(f"Remove from cart error: {e}")
        return f"Error removing from cart: {str(e)}"

@tool
def clear_cart(user_id: str) -> str:
    """Clear all items from the user's shopping cart.
    Argument: user_id (string UUID)
    """
    try:
        user_id = clean_input_string(user_id, "user_id")
        res = supabase_admin.table("cart").delete().eq("user_id", user_id).execute()
        return "Your cart has been successfully cleared."
    except Exception as e:
        logger.error(f"Clear cart error: {e}")
        return f"Error clearing cart: {str(e)}"

@tool
def add_medicine_to_cart(input_str: str) -> str:
    """Add a medicine to the user's shopping cart.
    Input MUST be a JSON string: {"user_id": "...", "medicine_name": "...", "quantity": 1}
    """
    import json
    try:
        # Robust parsing
        data = {}
        try:
            start = input_str.find('{')
            end = input_str.rfind('}')
            if start != -1 and end != -1:
                data = json.loads(input_str[start:end+1])
            else:
                data = json.loads(input_str)
        except:
             return "Error: Input must be a JSON object with user_id, medicine_name and quantity."

        user_id = data.get("user_id")
        medicine_name = data.get("medicine_name")
        quantity = int(data.get("quantity", 1))

        if not user_id or not medicine_name:
            return "Error: user_id and medicine_name are required."

        # 1. Resolve medicine ID
        med_res = supabase_admin.rpc("search_medicines", {"search_term": medicine_name}).execute()
        if not med_res.data:
            # Fallback to substitute search if not found in main inventory
            sub_info = suggest_generic_substitutes(medicine_name)
            return f"Could not find medicine '{medicine_name}'. {sub_info}"
        
        medicine = med_res.data[0]
        if medicine.get('stock', 0) <= 0:
            sub_info = suggest_generic_substitutes(medicine_name)
            return f"'{medicine['name']}' is currently out of stock. {sub_info}"
        
        med_id = medicine['id']

        # 2. Check if already in cart
        cart_res = supabase_admin.table("cart").select("*").eq("user_id", user_id).eq("medicine_id", med_id).execute()
        
        if cart_res.data and len(cart_res.data) > 0:
            # Update quantity
            old_qty = cart_res.data[0]['quantity']
            new_qty = old_qty + quantity
            supabase_admin.table("cart").update({"quantity": new_qty, "updated_at": "now()"}).eq("id", cart_res.data[0]['id']).execute()
            return f"Successfully updated '{medicine['name']}' in cart. There were {old_qty} units already, and I've added {quantity} more. Your new total is {new_qty} units."
        else:
            # Insert new
            supabase_admin.table("cart").insert({
                "user_id": user_id,
                "medicine_id": med_id,
                "quantity": quantity
            }).execute()
            return f"Successfully added {quantity} units of '{medicine['name']}' to your cart."

    except Exception as e:
        logger.error(f"Add to cart error: {e}")
        return f"Error adding to cart: {str(e)}"

@tool
def place_medicine_order(input_str: str) -> str:
    """Place a medicine order. This tool deducts funds from the user's wallet.
    Input MUST be a JSON string: {"user_id": "...", "medicine_name": "...", "quantity": 1, "delivery_address": "...", "prescription_url": "optional_url"}
    """
    import json
    try:
        # Robust JSON extraction
        curr_str = input_str.strip()
        start = curr_str.find('{')
        end = curr_str.rfind('}')
        if start != -1 and end != -1:
            data = json.loads(curr_str[start:end+1])
        else:
            return "Error: Invalid input format. Please send a valid JSON block."

        user_id = data.get("user_id")
        medicine_name = data.get("medicine_name")
        quantity_val = data.get("quantity")
        
        # S scavenge quantity from history if missing or 1 (default)
        if (not quantity_val or quantity_val == 1) and user_id in store:
            import re
            history = store[user_id].messages
            # Look at last 4 human messages for numbers
            for msg in reversed(history):
                if hasattr(msg, 'content') and not hasattr(msg, 'tool_calls'):
                    numbers = re.findall(r'\b(\d{1,3})\b', msg.content)
                    if numbers:
                        quantity_val = int(numbers[0])
                        break
        
        quantity = int(quantity_val or 1)
        delivery_address = data.get("delivery_address")
        
        # Scavenge address from profile/history if missing
        if not delivery_address or delivery_address in ["Default Address", "...", "None", "not set", "None reported", ""]:
            # Try history skip first, let tool logic handle profile fetch
            pass

        prescription_url = data.get("prescription_url")

        if not user_id or not medicine_name:
            return "Error: user_id and medicine_name are required."

        # 1. Verify medicine exists and check prescription requirement
        med_res = supabase_admin.rpc("search_medicines", {"search_term": medicine_name}).execute()
        if not hasattr(med_res, 'data') or not med_res.data:
            sub_info = suggest_generic_substitutes(medicine_name)
            return f"Medicine '{medicine_name}' not found or out of stock. {sub_info}"
        
        # Exact match logic to prevent ordering wrong variant
        medicine = med_res.data[0]
        for m in med_res.data:
            if m['name'].lower() == medicine_name.lower():
                medicine = m
                break

        if medicine.get('stock', 0) < quantity:
            sub_info = suggest_generic_substitutes(medicine_name)
            return f"Insufficient stock. Only {medicine.get('stock', 0)} units of {medicine['name']} are available. {sub_info}"
        
        if medicine.get('prescription_required') and not prescription_url:
            return f"Error: '{medicine['name']}' requires a prescription. Please upload one before ordering."

        # 2. Fetch User Profile for details, address and balance
        profile_res = supabase_admin.table("user_profiles").select("full_name, age, gender, wallet_balance, fcm_token, address").eq("id", user_id).single().execute()
        
        if not hasattr(profile_res, 'data') or profile_res.data is None:
            return "Error: Could not retrieve your profile. Please ensure it is set up."
            
        profile = profile_res.data
        
        # fallback to profile address if placeholder or missing
        profile_address = profile.get('address')
        if not delivery_address or delivery_address in ["Default Address", "...", "None", "not set", "None reported", ""]:
            if profile_address and profile_address not in ["None", "Not set", "None reported", ""]:
                delivery_address = profile_address
            else:
                return "Error: No delivery address found. Please provide an address or update your profile."

        current_balance = float(profile.get('wallet_balance', 0))
        total_price = float(medicine.get('price', 0)) * quantity

        if current_balance < total_price:
            # Handle Insufficient Balance: Add to Cart
            try:
                cart_data = {
                    "user_id": user_id,
                    "medicine_id": medicine['id'],
                    "quantity": quantity
                }
                supabase_admin.table("cart").insert(cart_data).execute()
                return (f"Your balance (₹{current_balance}) is too low for this order (₹{total_price}). "
                        f"I have added {quantity} units of {medicine['name']} to your cart. "
                        "You can pay via Razorpay in the cart section to complete your order.")
            except Exception as e:
                return f"Insufficient balance and failed to add to cart: {str(e)}"

        # 3. Process Transaction (Sync user_profiles and wallets tables)
        new_balance = current_balance - total_price
        
        # A. Update user_profiles
        supabase_admin.table("user_profiles").update({"wallet_balance": new_balance}).eq("id", user_id).execute()
        
        # B. Sync wallets table and create transaction
        wallet_id = None
        try:
            wallet_res = supabase_admin.table("wallets").select("id").eq("user_id", user_id).single().execute()
            if hasattr(wallet_res, 'data') and wallet_res.data:
                wallet_id = wallet_res.data['id']
                supabase_admin.table("wallets").update({"balance": new_balance}).eq("id", wallet_id).execute()
                
                # C. Log in wallet_transactions
                supabase_admin.table("wallet_transactions").insert({
                    "wallet_id": wallet_id,
                    "amount": total_price,
                    "transaction_type": "payment",
                    "status": "completed",
                    "description": f"Payment for {quantity}x {medicine['name']}"
                }).execute()
        except Exception as e:
            logger.error(f"Wallet/Transaction sync failed: {str(e)}")

        # 4. Create Order Records
        order_data = {
            "user_id": user_id,
            "customer_name": profile.get("full_name"),
            "patient_id": user_id, 
            "patient_age": profile.get("age"),
            "patient_gender": profile.get("gender"),
            "total_amount": total_price,
            "status": "pending",
            "payment_status": "successful",
            "payment_method": "wallet",
            "delivery_address": delivery_address,
            "prescription_url": prescription_url
        }
        order_res = supabase_admin.table("orders").insert(order_data).execute()
        
        if not hasattr(order_res, 'data') or not order_res.data:
            return "Payment successful, but failed to create order. Please contact support."
            
        order = order_res.data[0]
        order_uuid = order['id']
        short_id = str(order_uuid)[:8].upper()
        
        # 5. Add Order Item
        supabase_admin.table("order_items").insert({
            "order_id": order_uuid,
            "medicine_id": medicine['id'],
            "name": medicine['name'],
            "quantity": quantity,
            "price": medicine['price']
        }).execute()

        # 6. Update Medicine Inventory
        new_stock = medicine['stock'] - quantity
        supabase_admin.table("medicines").update({"stock": new_stock}).eq("id", medicine['id']).execute()

        # 7. Push Notification
        fcm_token = profile.get("fcm_token")
        if fcm_token:
            try:
                import httpx
                # Calling push-notification edge function
                func_url = f"{SUPABASE_URL}/functions/v1/push-notification"
                headers = {"Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}", "Content-Type": "application/json"}
                payload = {
                    "fcm_token": fcm_token,
                    "type": "order",
                    "title": "Order Confirmed!",
                    "body": f"Your order for {quantity}x {medicine['name']} has been placed successfully."
                }
                with httpx.Client() as client:
                    client.post(func_url, json=payload, headers=headers)
            except Exception as e:
                logger.error(f"FCM Notification failed: {str(e)}")

        return (f"Order placed successfully! Order ID: #{short_id}. "
                f"Amount ₹{total_price} deducted from wallet. New balance: ₹{new_balance}. "
                "You can view and track your order in the 'My Orders' section.")
    except Exception as e:
        return f"Critical error during ordering: {str(e)}"

# ------------------ AGENT ------------------
tools = [
    check_medicine_inventory,
    get_medicine_details,
    get_user_profile,
    suggest_generic_substitutes,
    place_medicine_order,
    add_medicine_to_cart,
    remove_from_cart,
    clear_cart
]

# ------------------ REACT AGENT ------------------
react_system_prompt = """You are PharmaVoice AI, a highly empathetic and professional human-like health assistant.
Your goal is to have a natural, helpful conversation with the user.
You have access to tools to help the user with their health, medicine, and profile.

TOOLS:
------
{tools}

FORMATTING RULES:
-----------------
To use a tool, you MUST use this format EXACTLY:
Thought: Do I need to use a tool? Yes
Action: the action to take, should be one of [{tool_names}]
Action Input: the EXACT input for the tool (must be a JSON block or string as specified)
Observation: the result of the action
... (this Thought/Action/Action Input/Observation can repeat)

When you are ready to talk to the user, you MUST use this format:
Thought: I now know the final answer
Final Answer: [your response here]

CRITICAL: Never omit 'Final Answer:'. If you just wrote a Thought, you MUST follow it with either an Action or a Final Answer.

PROACTIVE KNOWLEDGE:
-------------------
1. At the START of every conversation (when Chat History is empty or conversation just began), you MUST call 'get_user_profile' to know who you are talking to (their name, allergies, address).
2. Use this profile information to personalize your greeting (e.g., "Hello [Name]!") and to check for allergies/chronic conditions before suggesting medicines.

ORDER FLOW & LOGIC:
------------------
1. When a user wants to order a medicine (e.g., "I want to order Crocin"):
   a. Call 'get_medicine_details' to check price and if a prescription is REQUIRED.
   b. Inform the user of the price.
   c. If prescription is NOT REQUIRED:
      - Ask for the quantity.
      - Once quantity is given, ask for order confirmation.
      - Call 'place_medicine_order' only AFTER confirmation.
   d. If prescription IS REQUIRED:
      - Tell the user a prescription is required and ask them to upload it.
      - Check the 'Prescription' field in the context. If it is 'None', WAIT for the user to upload it.
      - Once 'Prescription' is an image URL (not 'None'), proceed to ask for quantity and confirmation.
      - Call 'place_medicine_order' and ensure 'prescription_url' is passed.

INVENTORY LOGIC:
---------------
1. When asked to "check my inventory" or "what do I have?":
   - If they specify a medicine (e.g., "Do I have Crocin?"), call 'check_medicine_inventory' with that name.
   - If they don't specify a name or just say "show my inventory", call 'check_medicine_inventory' with "medicine_name": "all".
   - If a specific search returns nothing, inform the user but also offer to show their ENTIRE inventory by calling the tool with "all".

SUBSTITUTE LOGIC:
----------------
1. If a medicine is OUT OF STOCK or NOT FOUND, call 'suggest_generic_substitutes'.
2. If the tool response starts with 'MATCHES_FOUND':
   - Inform the user these ARE available in our store.
   - You MAY offer to add them to the cart or place an order.
3. If the tool response starts with 'NO_STORE_MATCH':
   - Inform the user these are general medical suggestions only.
   - CRITICAL: Do NOT offer to order or add these to the cart, as they are not in our database.
4. Always include the medical consultation disclaimer.

CART MANAGEMENT LOGIC:
----------------------
1. If the user wants to add an item to the cart: Use 'add_medicine_to_cart'.
2. If the user wants to remove an item (e.g., "Remove Crocin from my cart"): Use 'remove_from_cart'.
3. If the user wants to empty or clear their cart: Use 'clear_cart'.
4. After any cart action, confirm the result to the user.

Guidelines for Human-like Conversation:
1. Address the user by their name when appropriate.
2. Be empathetic and supportive. If they mention being sick or needing medicine, show concern.
3. Avoid sounding like a robot. Use natural transitions and varied sentence structures.
4. Keep responses concise but warm—perfect for voice interaction.

CRITICAL INSTRUCTIONS:
1. Always respond in the SAME LANGUAGE as the user (Hindi, Spanish, etc.).
2. ADDRESS PRIORITY: ALWAYS fetch delivery address from 'get_user_profile' and use it automatically for orders.
3. NO HALLUCINATED WAITING: NEVER say "Wait a moment" or "Processing" in your Final Answer.
4. DO NOT mention stock or specific medical store names unless explicitly asked.

Current Context:
User ID: {user_id}
Preferred Language: {language}
Prescription: {image_url}

Chat History:
{chat_history}

Question: {input}
Thought: {agent_scratchpad}
"""

# Create the ReAct agent manually to handle variables better
from langchain.agents.format_scratchpad import format_log_to_str
from langchain.agents.output_parsers import ReActSingleInputOutputParser
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

# Optimized prompt for ReAct
tools_desc = render_text_description(tools)
tool_names = ", ".join([t.name for t in tools])

prompt = PromptTemplate.from_template(react_system_prompt)
prompt = prompt.partial(
    tools=tools_desc,
    tool_names=tool_names
)

# Helper to format history into string for ReAct
def format_history_to_string(messages):
    if not messages: return "No history yet."
    if isinstance(messages, str): return messages
    res = ""
    try:
        for m in messages:
            role = "User"
            if hasattr(m, 'type'): role = "User" if m.type == "human" else "Assistant"
            elif isinstance(m, dict): role = "User" if m.get('role') == 'user' else "Assistant"
            
            content = ""
            if hasattr(m, 'content'): content = m.content
            elif isinstance(m, dict): content = m.get('content', '')
            
            if content: res += f"{role}: {content}\n"
    except: pass
    return res

# Custom agent chain for better control
agent = (
    {
        "input": lambda x: x["input"],
        "user_id": lambda x: x.get("user_id", "Unknown"),
        "language": lambda x: x.get("language", "English"),
        "image_url": lambda x: x.get("image_url", "None"),
        "chat_history": lambda x: format_history_to_string(x.get("chat_history", [])),
        "agent_scratchpad": lambda x: format_log_to_str(x["intermediate_steps"]),
    }
    | prompt
    | llm.bind(stop=["\nObservation:"])
    | ReActSingleInputOutputParser()
)

# Create the agent executor
agent_executor = AgentExecutor(
    agent=agent, 
    tools=tools, 
    verbose=True, 
    handle_parsing_errors=True,
    max_iterations=6,
    return_intermediate_steps=True
)

# Wrap agent executor with history
# Note: Input must match what we pass in chat()
agent_with_chat_history = RunnableWithMessageHistory(
    agent_executor,
    get_session_history,
    input_messages_key="input",
    history_messages_key="chat_history",
)

import json
import httpx
from datetime import datetime
import uuid
import razorpay

# Initialize Razorpay client
razorpay_client = razorpay.Client(auth=(os.getenv("RAZORPAY_KEY_ID"), os.getenv("RAZORPAY_KEY_SECRET")))

class PaymentItem(BaseModel):
    medicine_id: int
    name: str
    quantity: int
    price: float

class OrderRequest(BaseModel):
    user_id: str
    payment_method: str
    reference_id: Optional[str] = None
    items: List[PaymentItem]
    total_amount: float
    delivery_address: Optional[str] = "Default Address"

@app.post("/place_order")
async def place_order(req: OrderRequest):
    try:
        # 1. Process Payment
        if req.payment_method == "wallet":
            # Check balance
            wallet = supabase_admin.table("wallets").select("id, balance").eq("user_id", req.user_id).single().execute()
            if not wallet.data:
                return {"success": False, "error": "Wallet not found"}
            
            balance = float(wallet.data['balance'])
            if balance < req.total_amount:
                return {"success": False, "error": "Insufficient wallet balance"}
            
            # Deduct balance
            new_balance = balance - req.total_amount
            supabase_admin.table("wallets").update({"balance": new_balance}).eq("user_id", req.user_id).execute()
            
            # Update user_profiles wallet_balance for UI consistency
            supabase_admin.table("user_profiles").update({"wallet_balance": new_balance}).eq("id", req.user_id).execute()
            
            # Record transaction
            supabase_admin.table("wallet_transactions").insert({
                "wallet_id": wallet.data['id'],
                "amount": -req.total_amount,
                "transaction_type": "payment",
                "description": f"Order payment for {len(req.items)} items",
                "status": "completed"
            }).execute()

        elif req.payment_method == "razorpay":
            # Verify Razorpay payment
            try:
                payment = razorpay_client.payment.fetch(req.reference_id)
                if payment['status'] not in ['captured', 'authorized']:
                    return {"success": False, "error": f"Razorpay payment not successful. Status: {payment['status']}"}
                
                # Verify amount (paisa to rupees)
                if float(payment['amount']) / 100 < req.total_amount:
                    return {"success": False, "error": "Payment amount mismatch"}
            except Exception as e:
                return {"success": False, "error": f"Razorpay verification failed: {str(e)}"}

        # 2. Create Order
        order_data = {
            "user_id": req.user_id,
            "total_amount": req.total_amount,
            "status": "pending",
            "payment_method": req.payment_method,
            "payment_reference": req.reference_id,
            "delivery_address": req.delivery_address,
        }
        order_res = supabase_admin.table("orders").insert(order_data).execute()
        if not order_res.data:
            return {"success": False, "error": "Failed to create order"}
        
        order_id = order_res.data[0]['id']

        # 3. Create Order Items & Update Stock
        for item in req.items:
            # Add to order_items table
            supabase_admin.table("order_items").insert({
                "order_id": order_id,
                "medicine_id": item.medicine_id,
                "name": item.name,
                "quantity": item.quantity,
                "price": item.price
            }).execute()

            # Update stock in medicines table
            med = supabase_admin.table("medicines").select("stock").eq("id", item.medicine_id).single().execute()
            if med.data:
                new_stock = max(0, int(med.data['stock']) - item.quantity)
                supabase_admin.table("medicines").update({"stock": new_stock}).eq("id", item.medicine_id).execute()

        return {"success": True, "order_id": order_id}

    except Exception as e:
        print(f"Error in place_order: {e}")
        return {"success": False, "error": str(e)}

class WalletTopupRequest(BaseModel):
    user_id: str
    amount: float
    razorpay_payment_id: str

@app.post("/topup_wallet")
async def topup_wallet(req: WalletTopupRequest):
    try:
        # 1. Verify Razorpay payment
        try:
            payment = razorpay_client.payment.fetch(req.razorpay_payment_id)
            if payment['status'] != 'captured' and payment['status'] != 'authorized':
                return {"success": False, "error": f"Payment not successful. Status: {payment['status']}"}
            
            # Check if amount matches (Razorpay amount is in paise)
            if float(payment['amount']) / 100 != req.amount:
                return {"success": False, "error": "Payment amount mismatch"}
                
        except Exception as e:
            return {"success": False, "error": f"Razorpay verification failed: {str(e)}"}
        
        # 2. Update Wallet
        wallet = supabase_admin.table("wallets").select("id, balance").eq("user_id", req.user_id).execute()
        
        new_balance = 0
        if not wallet.data:
            # Create wallet if not exists
            res = supabase_admin.table("wallets").insert({"user_id": req.user_id, "balance": req.amount}).execute()
            wallet_id = res.data[0]['id']
            new_balance = req.amount
        else:
            wallet_id = wallet.data[0]['id']
            new_balance = float(wallet.data[0]['balance']) + req.amount
            supabase_admin.table("wallets").update({"balance": new_balance}).eq("user_id", req.user_id).execute()

        # Update user_profiles wallet_balance for UI consistency
        supabase_admin.table("user_profiles").update({"wallet_balance": new_balance}).eq("id", req.user_id).execute()

        # 3. Record transaction
        supabase_admin.table("wallet_transactions").insert({
            "wallet_id": wallet_id,
            "amount": req.amount,
            "transaction_type": "deposit",
            "reference_id": req.razorpay_payment_id,
            "description": "Wallet top-up via Razorpay",
            "status": "completed"
        }).execute()

        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

class ChatRequest(BaseModel):
    message: str
    user_id: str
    language: Optional[str] = "English"
    image_url: Optional[str] = None
    extracted_medicines: Optional[List[str]] = None

@app.post("/chat")
async def chat(req: ChatRequest):
    try:
        # 1. Process Extracted Medicines if provided (Auto-add to cart)
        auto_cart_msg = ""
        if req.extracted_medicines:
            for med_name in req.extracted_medicines:
                med_res = supabase_admin.table("medicines").select("*").ilike("name", f"%{med_name}%").limit(1).execute()
                if med_res.data and len(med_res.data) > 0:
                    med = med_res.data[0]
                    existing = supabase_admin.table("cart").select("*").eq("user_id", req.user_id).eq("medicine_id", med["id"]).execute()
                    if not (existing.data and len(existing.data) > 0):
                        supabase_admin.table("cart").insert({
                            "user_id": req.user_id,
                            "medicine_id": med["id"],
                            "quantity": med.get("min_order_quantity", 1)
                        }).execute()
                        auto_cart_msg += f"- {med['name']} added to cart.\n"
                    else:
                        auto_cart_msg += f"- {med['name']} is already in your cart.\n"

        # 2. Execute agent with proper session history and context
        # We pass additional context in the input string for the ReAct agent
        input_with_context = f"{req.message}\n\nContext:\nUser ID: {req.user_id}\nLanguage: {req.language}\nPrescription Image: {req.image_url or 'None'}\n{f'Auto-added to cart: {auto_cart_msg}' if auto_cart_msg else ''}"
        
        response = agent_with_chat_history.invoke(
            {
                "input": input_with_context,
                "user_id": req.user_id,
                "language": req.language,
                "image_url": req.image_url or "None"
            },
            config={"configurable": {"session_id": req.user_id}},
        )
        
        output = response.get('output', "I'm sorry, I couldn't process that.")
        
        # 3. Robust detection: check if any tool result explicitly mentioned prescription requirement
        require_prescription = False
        try:
            isteps = response.get("intermediate_steps", [])
            for action, observation in isteps:
                obs_str = str(observation).upper()
                if "PRESCRIPTION: REQUIRED" in obs_str or "PRESCRIPTION REQUIRED: YES" in obs_str:
                    require_prescription = True
                    break
                elif "PRESCRIPTION: NOT REQUIRED" in obs_str or "PRESCRIPTION REQUIRED: NO" in obs_str:
                    require_prescription = False
        except:
            pass

        if not require_prescription:
            o_lower = output.lower()
            has_presc_word = "prescription" in o_lower or "प्रिस्क्रिप्शन" in o_lower
            is_asking_to_upload = any(w in o_lower for w in ["upload", "अपलोड", "send", "भेजें"])
            is_saying_required = any(w in o_lower for w in ["required", "आवश्यक", "needed", "चाहिए"])
            not_required = any(phrase in o_lower for phrase in ["not required", "no prescription", "आवश्यकता नहीं", "बिना प्रिस्क्रिप्शन"])
            
            if has_presc_word and (is_asking_to_upload or is_saying_required) and not not_required:
                require_prescription = True
        
        clean_output = output.replace("**", "")
        return {
            "reply": clean_output, 
            "require_prescription": require_prescription,
            "should_exit": "goodbye" in clean_output.lower() or "thank you" in clean_output.lower()
        }
    except Exception as e:
        print(f"Chat Error: {e}")
        import traceback
        traceback.print_exc()
        return {"reply": "I encountered a technical issue. Please try again.", "should_exit": False}

@app.post("/translate_batch")
async def translate_batch(texts: List[str], target_lang: str):
    try:
        if not texts:
            return {"translated_texts": []}
        
        # English is default, no translation needed
        if target_lang.lower() == "english":
            return {"translated_texts": texts}

        # Format texts for GPT
        texts_json = json.dumps(texts)
        translation_prompt = ChatPromptTemplate.from_messages([
            ("system", "You are a professional translator. Translate the following JSON list of strings to {target_lang}. Keep technical terms or brand names like 'PharmaCo' as they are. Return ONLY a JSON list of translated strings in the exact same order."),
            ("user", "{texts_json}")
        ])
        chain = translation_prompt | llm
        response = chain.invoke({"texts_json": texts_json, "target_lang": target_lang})
        
        # Parse the JSON response
        try:
            translated_list = json.loads(response.content)
            if isinstance(translated_list, list) and len(translated_list) == len(texts):
                return {"translated_texts": translated_list}
        except:
            pass
            
        return {"error": "Failed to parse batch translation", "translated_texts": texts}
    except Exception as e:
        return {"error": str(e), "translated_texts": texts}

@app.post("/translate")
async def translate_text(text: str, target_lang: str):
    try:
        translation_prompt = ChatPromptTemplate.from_messages([
            ("system", "You are a professional translator. Translate the following text to {target_lang}. Keep technical terms or brand names like 'PharmaCo' as they are. Return ONLY the translated text."),
            ("user", "{text}")
        ])
        chain = translation_prompt | llm
        response = chain.invoke({"text": text, "target_lang": target_lang})
        return {"translated_text": response.content}
    except Exception as e:
        return {"error": str(e)}

# --- PYDANTIC MODELS ---

class PrescriptionProcessRequest(BaseModel):
    user_id: str
    image_url: str
    cart_items: Optional[List[str]] = None

@app.post("/validate_prescription_cart")
async def validate_prescription_cart(req: PrescriptionProcessRequest):
    """
    Processes a prescription image using PrescriptoAI and validates it against cart items.
    Returns which cart items are present in the prescription.
    """
    try:
        # 1. Download image
        async with httpx.AsyncClient(timeout=30.0) as client:
            img_response = await client.get(req.image_url)
            if img_response.status_code != 200:
                return {"success": False, "error": "Failed to download image"}
            image_content = img_response.content

        # 2. Call PrescriptoAI
        async with httpx.AsyncClient(follow_redirects=True, timeout=120.0) as client:
            api_url = "https://www.prescriptoai.com/api/v1/prescription/extract"
            files = {'prescription': ('prescription.jpg', image_content, 'image/jpeg')}
            headers = {"Authorization": f"Bearer {PRESCRIPTO_API_KEY}", "Accept": "application/json"}
            
            response = await client.post(api_url, headers=headers, files=files)
            
            if response.status_code != 200:
                error_msg = f"AI Error ({response.status_code})"
                if response.status_code == 503:
                    error_msg = "Prescription AI service is temporarily busy. Please try again."
                elif response.status_code == 400:
                    error_msg = "Invalid image. Please upload a clear photo of a real prescription."
                
                # Check if the response contains a more specific error message from the API
                try:
                    api_error = response.json()
                    if api_error.get("error"):
                        error_msg = api_error["error"]
                except:
                    pass
                    
                return {"success": False, "error": error_msg}
            
            result = response.json()
            print(f"DEBUG: validate_prescription_cart - PrescriptoAI Full Response: {json.dumps(result, indent=2)}")
            data_obj = result.get("data", {})
            prescription_obj = data_obj.get("prescription", {})
            medications = prescription_obj.get("medications", [])
            
            if not medications:
                return {
                    "success": False, 
                    "error": "No medicines detected. Please ensure you uploaded a valid prescription."
                }
            
            extracted_names = [m.get("name", "").lower() for m in medications if m.get("name")]
            
            # 3. Match with cart items if provided
            validated_items = []
            missing_items = []
            
            if req.cart_items:
                for item in req.cart_items:
                    item_lower = item.lower()
                    # Simple fuzzy matching: check if cart item name exists in extracted names or vice versa
                    matched = any(item_lower in extracted or extracted in item_lower for extracted in extracted_names)
                    if matched:
                        validated_items.append(item)
                    else:
                        missing_items.append(item)

            return {
                "success": True,
                "extracted_medicines": extracted_names,
                "validated_items": validated_items,
                "missing_items": missing_items,
                "prescription_details": {
                    "doctor": prescription_obj.get("doctor_name"),
                    "date": prescription_obj.get("date"),
                    "diagnosis": prescription_obj.get("diagnosis")
                }
            }
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.post("/process_prescription_inventory")
async def process_prescription_inventory(req: PrescriptionProcessRequest):
    """
    Processes a prescription image using PrescriptoAI, extracts medicine data,
    and adds them to the user's inventory.
    """
    try:
        print(f"DEBUG: Processing prescription for user {req.user_id} from {req.image_url}")
        
        # 1. Download the image from Supabase
        # Increased timeout to 30s for downloading the image
        async with httpx.AsyncClient(timeout=30.0) as client:
            img_response = await client.get(req.image_url)
            if img_response.status_code != 200:
                return {"success": False, "error": f"Failed to download image from Supabase: {img_response.status_code}"}
            image_content = img_response.content

        # 2. Call PrescriptoAI API using multipart/form-data as per documentation
        # Added follow_redirects=True to handle the 307 response
        # Increased timeout to 120s for AI processing
        async with httpx.AsyncClient(follow_redirects=True, timeout=120.0) as client:
            # Domain from screenshot is prescriptoai.com
            api_url = "https://www.prescriptoai.com/api/v1/prescription/extract"
            
            print(f"DEBUG: Calling PrescriptoAI ({api_url}) with multipart file")
            
            # Explicitly setting the fields to match the documentation's multipart requirements
            # The field name MUST be 'prescription' as per the cURL example
            files = {
                'prescription': ('prescription.jpg', image_content, 'image/jpeg')
            }
            headers = {
                "Authorization": f"Bearer {PRESCRIPTO_API_KEY}",
                "Accept": "application/json"
            }
            
            response = await client.post(
                api_url,
                headers=headers,
                files=files
            )
            
            print(f"DEBUG: PrescriptoAI response status: {response.status_code}")
            
            if response.status_code != 200:
                print(f"ERROR: PrescriptoAI returned {response.status_code}: {response.text}")
                return {"success": False, "error": f"PrescriptoAI Error ({response.status_code}): {response.text}"}
            
            result = response.json()
            print(f"DEBUG: PrescriptoAI response JSON: {result}")
            
            # The API response structure from your logs:
            # result['data']['prescription']['medications']
            data_obj = result.get("data", {})
            prescription_obj = data_obj.get("prescription", {})
            medicines = prescription_obj.get("medications", [])
            
            # Fallbacks for different structures
            if not medicines:
                medicines = data_obj.get("medicines", [])
            if not medicines:
                medicines = result.get("medicines", [])
            
            if not medicines:
                return {
                    "success": False, 
                    "error": "No medicines detected in the prescription.",
                    "debug_json": result
                }
            
            # 3. Process extracted medicines
            detected_medicines = []
            
            # Extract test/extra items if any
            prescription_notes = prescription_obj.get("notes", "")
            diagnosis = prescription_obj.get("diagnosis", "")
            
            for med in medicines:
                # API uses 'name' for medicine name
                name = med.get("name") or med.get("medicine_name")
                if not name: continue
                
                # We no longer insert directly into the database here.
                # Instead, we return the parsed data to the frontend for verification.
                detected_medicines.append({
                    "name": name,
                    "frequency": med.get("frequency", "1"),
                    "dosage": med.get("dosage", ""),
                    "duration": med.get("duration", "")
                })
            
            return {
                "success": True, 
                "message": f"Detected {len(detected_medicines)} medicines",
                "medicines": [m['name'] for m in detected_medicines],
                "raw_data": result 
            }
            
    except Exception as e:
        print(f"ERROR in process_prescription_inventory: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}

class TabletScanRequest(BaseModel):
    user_id: str
    ocr_text: str

@app.post("/extract_medicine_name")
async def extract_medicine_name(req: TabletScanRequest):
    """
    Uses LLM to extract a clean medicine name from raw OCR text.
    """
    try:
        extraction_prompt = ChatPromptTemplate.from_messages([
            ("system", "You are a medical assistant. Extract ONLY the primary medicine/tablet name from the following OCR text. Ignore dosages, manufacturers, or unrelated text. Return ONLY the name, nothing else. If no medicine name is found, return 'Unknown'."),
            ("user", "{ocr_text}")
        ])
        chain = extraction_prompt | llm
        response = chain.invoke({"ocr_text": req.ocr_text})
        return {"medicine_name": response.content.strip()}
    except Exception as e:
        return {"error": str(e)}

@app.post("/scan_tablet")
async def scan_tablet(req: TabletScanRequest, image_url: str):
    """
    Extracts medicine name from a tablet photo using PrescriptoAI.
    """
    try:
        print(f"DEBUG: Scanning tablet for user {req.user_id} from {image_url}")
        
        # 1. Download image
        async with httpx.AsyncClient(timeout=30.0) as client:
            img_response = await client.get(image_url)
            if img_response.status_code != 200:
                return {"success": False, "error": "Failed to download image"}
            image_content = img_response.content

        # 2. Call PrescriptoAI
        async with httpx.AsyncClient(follow_redirects=True, timeout=60.0) as client:
            api_url = "https://www.prescriptoai.com/api/v1/prescription/extract"
            files = {'prescription': ('tablet.jpg', image_content, 'image/jpeg')}
            headers = {
                "Authorization": f"Bearer {PRESCRIPTO_API_KEY}",
                "Accept": "application/json"
            }
            
            response = await client.post(api_url, headers=headers, files=files)
            
            if response.status_code != 200:
                return {"success": False, "error": f"AI Error: {response.status_code}"}
            
            result = response.json()
            data_obj = result.get("data", {})
            prescription_obj = data_obj.get("prescription", {})
            meds = prescription_obj.get("medications", [])
            
            if meds:
                med = meds[0]
                return {
                    "success": True,
                    "medicine_name": med.get("name") or med.get("medicine_name"),
                    "quantity": 10,
                    "daily_usage": 1.0
                }
            
            return {"success": False, "error": "Could not identify tablet"}
            
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.post("/chat")
async def chat(req: ChatRequest):
    try:
        # Pass the message AND context variables to the agent
        response = agent_with_chat_history.invoke(
            {
                "input": req.message,
                "user_id": req.user_id,
                "language": req.language,
                "image_url": req.image_url or "None"
            },
            config={"configurable": {"session_id": req.user_id}},
        )
        
        output = response.get('output', "I'm sorry, I couldn't process that.")
        
        # Robust detection: check if any tool result explicitly mentioned prescription requirement
        require_prescription = False
        try:
            # ReAct agent stores tool runs in intermediate_steps
            isteps = response.get("intermediate_steps", [])
            for action, observation in isteps:
                obs_str = str(observation).upper()
                # Explicit check for prescription REQUIRED in get_medicine_details or check_medicine_inventory
                if "PRESCRIPTION: REQUIRED" in obs_str or "PRESCRIPTION REQUIRED: YES" in obs_str:
                    require_prescription = True
                    break
                # If it explicitly says NOT REQUIRED, ensure we don't trigger it
                elif "PRESCRIPTION: NOT REQUIRED" in obs_str or "PRESCRIPTION REQUIRED: NO" in obs_str:
                    require_prescription = False
                    # Don't break yet, another tool might say otherwise (unlikely but safe)
        except:
            pass

        # Fallback to keyword check (supporting Hindi) ONLY if not already determined by tool
        if not require_prescription:
            o_lower = output.lower()
            # Only trigger if it explicitly asks to UPLOAD or says it IS REQUIRED
            has_presc_word = "prescription" in o_lower or "प्रिस्क्रिप्शन" in o_lower
            is_asking_to_upload = any(w in o_lower for w in ["upload", "अपलोड", "send", "भेजें"])
            is_saying_required = any(w in o_lower for w in ["required", "आवश्यक", "needed", "चाहिए"])
            
            # Anti-trigger: If the response says "not required" or "no prescription needed"
            not_required = any(phrase in o_lower for phrase in ["not required", "no prescription", "आवश्यकता नहीं", "बिना प्रिस्क्रिप्शन"])
            
            if has_presc_word and (is_asking_to_upload or is_saying_required) and not not_required:
                require_prescription = True
        
        # Clean markdown bolding characters as requested
        clean_output = output.replace("**", "")
        
        # Intelligent Exit Detection
        should_exit = False
        exit_keywords = ["bye", "goodbye", "exit", "quit", "leave", "नमस्ते", "अलविदा", "फिर मिलेंगे"]
        o_lower = output.lower()
        if any(word in o_lower for word in exit_keywords) and len(o_lower.split()) < 15:
            should_exit = True

        return {
            "reply": clean_output, 
            "require_prescription": require_prescription,
            "should_exit": should_exit
        }
    except Exception as e:
        print(f"Chat Error: {e}")
        return {"reply": "I encountered a technical issue. Please try again."}

class TTSRequest(BaseModel):
    text: str
    voice_id: Optional[str] = "21m00Tcm4TlvDq8ikWAM"

@app.post("/tts")
async def text_to_speech(req: TTSRequest):
    """Securely proxy TTS requests to ElevenLabs with quota detection."""
    try:
        eleven_labs_key = os.getenv("ELEVENLABS_API_KEY", "sk_1cd61d73a491e8a2de10f920fadead492d765bb08ec96ce7")
        api_url = f"https://api.elevenlabs.io/v1/text-to-speech/{req.voice_id}"
        
        headers = {
            "Accept": "audio/mpeg",
            "xi-api-key": eleven_labs_key,
            "Content-Type": "application/json"
        }
        
        data = {
            "text": req.text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.5}
        }
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            print(f"DEBUG: Calling ElevenLabs with key starting with: {eleven_labs_key[:4]}...")
            response = await client.post(api_url, json=data, headers=headers)
            
            if response.status_code == 401 or response.status_code == 429:
                print(f"ElevenLabs Quota/Auth Error: {response.status_code} - {response.text}")
                return {"error": "ElevenLabs Quota Exceeded. Please update your API key."}
            
            if response.status_code != 200:
                print(f"ElevenLabs Error: {response.status_code} - {response.text}")
                return {"error": f"TTS failed: {response.status_code}"}
            
            import base64
            audio_base64 = base64.b64encode(response.content).decode("utf-8")
            return {"audio_base64": audio_base64}
    except Exception as e:
        return {"error": str(e)}

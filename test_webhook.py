import requests, json

url = 'https://nlhuukhyqnkniugrgtwp.supabase.co/functions/v1/send-delivery-email'
payload = {'type':'UPDATE','table':'orders','record':{'id':'test1234','status':'delivered','user_id':'a8b3eaba-eece-4cba-a496-5b8d2ed1fcc5','delivery_address':'123 Test Street'},'old_record':{'status':'processing'}}
headers = {'Content-Type': 'application/json'}
r = requests.post(url, json=payload, headers=headers)
print(f'Status: {r.status_code}')
print(f'Response: {r.text}')

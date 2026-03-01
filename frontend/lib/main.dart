import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/inventory_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen_v2.dart';
import 'theme/pharmaco_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/medicine_search_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/upload_prescription_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_completion_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/payment_failure_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/health_profile_screen.dart';
import 'services/supabase_service.dart';
import 'services/reminder_service.dart';
import 'services/localization_service.dart';
import 'screens/language_selection_screen.dart';
import 'screens/medicines_list_screen.dart';
import 'screens/s2s_conversation_page.dart';
import 'screens/app_tour_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_medicine_management.dart';
import 'screens/admin_order_management.dart';
import 'screens/admin_user_management.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase (Safe check if options missing)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed or already initialized: $e");
  }
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize Localization & load persistent data
  await LocalizationService.init();
  
  // Check initial state before running app
  final bool isFirstTime = await LocalizationService.isFirstTime();
  final bool isLoggedIn = Supabase.instance.client.auth.currentSession != null;
  
  // Initialize Reminder Service
  await ReminderService().initialize();
  
  runApp(MyApp(isFirstTime: isFirstTime, isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isFirstTime;
  final bool isLoggedIn;
  const MyApp({Key? key, required this.isFirstTime, required this.isLoggedIn}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late bool _isFirstTime;
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isFirstTime = widget.isFirstTime;
    _isLoggedIn = widget.isLoggedIn;
  }

  @override
  Widget build(BuildContext context) {
    String initialRoute;
    if (_isLoggedIn) {
      initialRoute = '/splash'; // Logged in users go to splash for profile/tour check
    } else {
      initialRoute = '/language-selection'; // Non-logged in users always see language selection
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PharmaCo',
      debugShowCheckedModeBanner: false,
      theme: PharmacoTheme.lightTheme,
      darkTheme: PharmacoTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        if (settings.name == '/payment-success') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              orderId: args['order_id'] ?? 'N/A',
              amount: args['amount'] ?? 0.0,
            ),
          );
        }
        if (settings.name == '/payment-failure') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PaymentFailureScreen(
              error: args['error'] ?? 'Unknown error',
            ),
          );
        }
        return null;
      },
      routes: {
        '/language-selection': (context) => const LanguageSelectionScreen(),
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreenV2(),
        '/chat': (context) => const ChatScreen(),
        '/medicines': (context) => const MedicinesListScreen(),
        '/medicine-search': (context) => const MedicineSearchScreen(),
        '/cart': (context) => const CartScreen(),
        '/my-orders': (context) => const MyOrdersScreen(),
        '/reminders': (context) => const ReminderScreen(),
        '/upload-prescription': (context) => const UploadPrescriptionScreen(),
        '/inventory': (context) => const InventoryScreen(),
        '/s2s-voice': (context) => const S2SConversationPage(),
        '/profile': (context) => const ProfileScreen(),
        '/profile-completion': (context) => const ProfileCompletionScreen(),
        '/app-tour': (context) => const AppTourScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/health-profile': (context) => const HealthProfileScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/admin-medicines': (context) => const AdminMedicineManagement(),
        '/admin-orders': (context) => const AdminOrderManagementScreen(),
        '/admin-users': (context) => const AdminUserManagementScreen(),
      },
    );
  }
}

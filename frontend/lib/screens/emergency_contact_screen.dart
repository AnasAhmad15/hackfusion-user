import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import '../widgets/pharmaco_button.dart';
import '../widgets/empty_state.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({super.key});

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  final _client = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        final data = await _client
            .from('emergency_contacts')
            .select()
            .eq('user_id', user.id);
        setState(() => _contacts = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching contacts: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('emergency_contacts').insert({
          'user_id': user.id,
          'name': _nameController.text,
          'phone_number': _phoneController.text,
        });
        _nameController.clear();
        _phoneController.clear();
        _fetchContacts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding contact: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContact(int id) async {
    setState(() => _isLoading = true);
    try {
      await _client.from('emergency_contacts').delete().eq('id', id);
      _fetchContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting contact: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: Padding(
        padding: const EdgeInsets.all(PharmacoTokens.space16),
        child: Column(
          children: [
            // Add contact form
            Container(
              padding: const EdgeInsets.all(PharmacoTokens.space16),
              decoration: BoxDecoration(
                color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                borderRadius: PharmacoTokens.borderRadiusCard,
                boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Contact Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: PharmacoTokens.space12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      hintText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: PharmacoTokens.space16),
                  PharmacoButton(
                    label: 'Add Contact',
                    icon: Icons.person_add_rounded,
                    onPressed: _isLoading ? null : _addContact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: PharmacoTokens.space24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Contacts', style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: PharmacoTokens.space12),
            Expanded(
              child: _isLoading && _contacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                      ? const EmptyState(
                          icon: Icons.contacts_outlined,
                          title: 'No contacts added yet',
                          subtitle: 'Add emergency contacts to stay safe',
                        )
                      : ListView.separated(
                          itemCount: _contacts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: PharmacoTokens.space8),
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? PharmacoTokens.darkSurface : PharmacoTokens.white,
                                borderRadius: PharmacoTokens.borderRadiusCard,
                                boxShadow: isDark ? null : PharmacoTokens.shadowZ1(),
                                border: isDark ? Border.all(color: PharmacoTokens.darkBorder) : null,
                              ),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: PharmacoTokens.borderRadiusCard),
                                leading: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: PharmacoTokens.emergencyBg,
                                    borderRadius: PharmacoTokens.borderRadiusSmall,
                                  ),
                                  child: const Icon(Icons.person_rounded, color: PharmacoTokens.error),
                                ),
                                title: Text(contact['name'], style: theme.textTheme.titleSmall),
                                subtitle: Text(contact['phone_number'],
                                    style: theme.textTheme.bodySmall?.copyWith(color: PharmacoTokens.neutral500)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: PharmacoTokens.error),
                                  onPressed: () => _deleteContact(contact['id']),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

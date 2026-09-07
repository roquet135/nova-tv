import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';

/// Formulaire d'ajout d'un abonnement (M3U, Xtream ou Stalker).
class AddPortalScreen extends StatefulWidget {
  const AddPortalScreen({super.key});

  @override
  State<AddPortalScreen> createState() => _AddPortalScreenState();
}

class _AddPortalScreenState extends State<AddPortalScreen> {
  PortalType _type = PortalType.m3u;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _mac = TextEditingController(text: '00:1A:79:');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _mac.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Donne un nom a cet abonnement');
      return;
    }
    if (_url.text.trim().isEmpty) {
      setState(() => _error = 'L adresse est obligatoire');
      return;
    }
    if (_type == PortalType.xtream &&
        (_user.text.trim().isEmpty || _pass.text.trim().isEmpty)) {
      setState(() => _error = 'Identifiant et mot de passe requis');
      return;
    }
    if (_type == PortalType.stalker && _mac.text.trim().length < 12) {
      setState(() => _error = 'Adresse MAC invalide');
      return;
    }

    final portal = Portal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      type: _type,
      url: _url.text.trim(),
      username: _user.text.trim(),
      password: _pass.text.trim(),
      macAddress: _mac.text.trim(),
    );
    await Storage.savePortal(portal);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GradientTitle('Nouvel abonnement', size: 26),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    children: PortalType.values.map((t) {
                      final sel = t == _type;
                      return GestureDetector(
                        onTap: () => setState(() => _type = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: sel ? NovaColors.brand : null,
                            color: sel ? null : NovaColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.label,
                            style: TextStyle(
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _type.hint,
                    style: const TextStyle(
                        color: NovaColors.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  _field(_name, 'Nom de l abonnement', Icons.label_outline),
                  _field(
                    _url,
                    _type == PortalType.m3u
                        ? 'URL de la playlist'
                        : 'Adresse du serveur',
                    Icons.link_rounded,
                  ),
                  if (_type == PortalType.xtream) ...[
                    _field(_user, 'Identifiant', Icons.person_outline),
                    _field(_pass, 'Mot de passe', Icons.lock_outline,
                        obscure: true),
                  ],
                  if (_type == PortalType.stalker)
                    _field(_mac, 'Adresse MAC', Icons.memory_rounded),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      NovaButton(
                        label: 'Enregistrer',
                        icon: Icons.check_rounded,
                        onTap: _save,
                      ),
                      const SizedBox(width: 14),
                      NovaButton(
                        label: 'Annuler',
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        style: const TextStyle(color: NovaColors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: NovaColors.textDim),
          prefixIcon: Icon(icon, color: NovaColors.textDim, size: 20),
          filled: true,
          fillColor: NovaColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: NovaColors.cyan, width: 2),
          ),
        ),
      ),
    );
  }
}

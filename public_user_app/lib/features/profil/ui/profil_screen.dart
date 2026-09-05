import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profil_models.dart';
import '../providers/profil_provider.dart';

/// Identité, spécialité et dossier du citoyen — pas de statut ni de dates de
/// traitement : un citoyen qui peut ouvrir l'application a nécessairement
/// un dossier approuvé, l'afficher n'apporterait rien. Le portefeuille reste
/// dans le bandeau d'accueil, pas dupliqué ici.
class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profilProvider.notifier).charger();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider.select((a) => a.session));
    final state = ref.watch(profilProvider);

    return SafeArea(
      child: state.chargement && state.dossier == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.authVert))
          : state.erreur != null && state.dossier == null
              ? _erreur(state.erreur!)
              : RefreshIndicator(
                  color: AppColors.authVert,
                  onRefresh: () => ref.read(profilProvider.notifier).charger(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _entete(session?.nomAffiche ?? '', session?.initiales ?? '?'),
                      const SizedBox(height: 20),
                      _carteContact(session?.email ?? '', state.dossier),
                      if (state.dossier != null) ...[
                        const SizedBox(height: 14),
                        _carteAdresse(state.dossier!),
                      ],
                      if (state.dossier?.chasseur != null) ...[
                        const SizedBox(height: 14),
                        _carteChasseur(state.dossier!.chasseur!),
                      ],
                      if (state.dossier?.apiculteur != null) ...[
                        const SizedBox(height: 14),
                        _carteApiculteur(state.dossier!.apiculteur!),
                      ],
                      if (state.dossier != null && state.dossier!.pieces.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _cartePieces(state.dossier!.pieces),
                      ],
                      const SizedBox(height: 28),
                      _boutonDeconnexion(context),
                    ],
                  ),
                ),
    );
  }

  Widget _erreur(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.errorText, size: 40),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(profilProvider.notifier).charger(),
                child: const Text('Réessayer', style: TextStyle(color: AppColors.authVert)),
              ),
            ],
          ),
        ),
      );

  Widget _entete(String nom, String initiales) => Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: AppColors.authVert,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initiales,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Text(nom,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      );

  Widget _section({required String titre, required List<Widget> lignes}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppDims.card),
          border: Border.all(color: AppColors.border, width: 0.6),
          boxShadow: AppShadows.champ,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            ...lignes,
          ],
        ),
      );

  Widget _ligne(String libelle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(libelle,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
            Expanded(
              child: Text(valeur,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  Widget _carteContact(String email, DossierCitoyen? dossier) => _section(
        titre: 'Contact',
        lignes: [
          _ligne('Email', email),
          if (dossier?.telephone != null && dossier!.telephone!.isNotEmpty)
            _ligne('Téléphone', dossier.telephone!),
        ],
      );

  Widget _carteAdresse(DossierCitoyen d) => _section(
        titre: 'Adresse',
        lignes: [
          _ligne('Gouvernorat', d.gouvernorat),
          _ligne('Délégation', d.delegation),
          if (d.secteur != null && d.secteur!.isNotEmpty) _ligne('Secteur', d.secteur!),
          if (d.adresse != null && d.adresse!.isNotEmpty) _ligne('Adresse', d.adresse!),
        ],
      );

  Widget _carteChasseur(ProfilChasseur c) => _section(
        titre: 'Permis de chasse',
        lignes: [
          _ligne('N° de permis', c.numeroPermisChasse),
          if (c.gouvernoratDelivrance != null)
            _ligne('Délivré à', c.gouvernoratDelivrance!),
          if (c.dateDelivrance != null) _ligne('Délivré le', _fmt(c.dateDelivrance!)),
          if (c.dateExpiration != null) _ligne('Expire le', _fmt(c.dateExpiration!)),
          _ligne('Détient une arme', c.possedeArme ? 'Oui' : 'Non'),
          if (c.possedeArme && c.numeroPermisDetention != null)
            _ligne('Permis de détention', c.numeroPermisDetention!),
          if (c.possedeArme && c.numeroPermisPortTransport != null)
            _ligne('Permis de port/transport', c.numeroPermisPortTransport!),
        ],
      );

  Widget _carteApiculteur(ProfilApiculteur a) => _section(
        titre: 'Registre apicole',
        lignes: [
          _ligne('Code apiculteur', a.codeComplet),
          _ligne('Colonies déclarées', '${a.nombreColoniesDeclare}'),
          if (a.dateCertificat != null) _ligne('Certificat du', _fmt(a.dateCertificat!)),
          if (a.ruchers.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 4),
              child: Text('Ruchers',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            ...a.ruchers.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.hive_outlined, size: 15, color: AppColors.authVert),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rucher n°${r.numero} — ${r.emplacement} (${r.nombreColonies} colonies)',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      );

  Widget _cartePieces(List<PieceJointe> pieces) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppDims.card),
          border: Border.all(color: AppColors.border, width: 0.6),
          boxShadow: AppShadows.champ,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documents transmis',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...pieces.map((p) => InkWell(
                  onTap: () => launchUrl(Uri.parse(p.url), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 17, color: AppColors.authVert),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.type.libelle,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textPrimary)),
                        ),
                        const Icon(Icons.open_in_new, size: 15, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      );

  Widget _boutonDeconnexion(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmerDeconnexion(context),
          icon: const Icon(Icons.logout, size: 18, color: AppColors.errorText),
          label: const Text('Déconnexion',
              style: TextStyle(color: AppColors.errorText, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.errorBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDims.controle)),
          ),
        ),
      );

  void _confirmerDeconnexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez ressaisir votre email et votre mot de passe pour vous reconnecter.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).deconnecter();
              context.go('/login');
            },
            child: const Text('Déconnexion',
                style: TextStyle(color: AppColors.errorText, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/printer_settings/presentation/pages/printer_settings_page.dart';
import '../../features/tenant/application/tenant_controller.dart';
import '../../features/tenant/presentation/pages/tenant_code_page.dart';
import '../../features/tickets/presentation/pages/new_ticket_page.dart';
import '../../features/tickets/presentation/pages/ticket_details_page.dart';
import '../../features/tickets/presentation/pages/tickets_history_page.dart';
import 'app_routes.dart';

/// Router provider. Rebuilds when tenant or auth state changes so the guard
/// re-evaluates on login/logout and on tenant switch.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final tenant = ref.read(tenantControllerProvider);
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onTenantCode = location == AppRoutes.tenantCode;
      final onLogin = location == AppRoutes.login;

      // 1. No barbershop chosen yet → tenant-code page.
      if (!tenant.hasCode) return onTenantCode ? null : AppRoutes.tenantCode;

      // 2. Barbershop chosen but auth still loading → wait.
      if (auth.isUnknown) return null;

      // 3. Not authenticated → login page.
      if (!auth.isAuthenticated) return onLogin ? null : AppRoutes.login;

      // 4. Authenticated → bounce off the pre-auth screens.
      if (onLogin || onTenantCode) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.tenantCode,
        name: 'tenant-code',
        builder: (_, _) => const TenantCodePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, _) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navShell) => _HomeShell(navShell: navShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.newSale,
                name: 'new-sale',
                builder: (_, _) => const NewTicketPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.salesHistory,
                name: 'sales-history',
                builder: (_, _) => const TicketsHistoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'ticket-details',
                    builder: (_, state) => TicketDetailsPage(
                      ticketId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.printerSettings,
                name: 'printer-settings',
                builder: (_, _) => const PrinterSettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (_, _) => AppRoutes.newSale,
      ),
    ],
  );
});

/// Bridges Riverpod state changes into a [Listenable] that GoRouter can
/// consume. GoRouter reruns `redirect` whenever this notifies, which is what
/// pushes users between the tenant-code / login / home screens.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(this._ref) {
    _ref.listen(tenantControllerProvider, (_, _) => notifyListeners());
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }

  // ignore: unused_field
  final Ref _ref;
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.navShell});

  final StatefulNavigationShell navShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navShell.currentIndex,
        onDestinationSelected: (i) => navShell.goBranch(
          i,
          initialLocation: i == navShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Nueva venta',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print),
            label: 'Impresora',
          ),
        ],
      ),
    );
  }
}

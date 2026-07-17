/// Public snapshot of a barbershop returned by `GET /tenants/lookup/:code`.
/// Used to render the tenant name/logo above the login form so the seller
/// sees which shop they're about to log into.
class TenantLookup {
  const TenantLookup({
    required this.name,
    required this.isActive,
    this.logo,
  });

  final String name;
  final String? logo;
  final bool isActive;
}

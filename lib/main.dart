// ============================================================================
// E-COMMERCE RIVERPOD DEMO
// Architecture en couches :
//   1. MODELS        -> classes de données immuables
//   2. DATA LAYER    -> repository (accès aux données, mocké)
//   3. PROVIDERS     -> logique métier / state management (Riverpod)
//   4. UI LAYER      -> widgets, ne contiennent AUCUNE logique métier
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ProviderScope(child: ECommerceApp()));
}

// ============================================================================
// 1. MODELS
// ============================================================================

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String emoji; // sert de "visuel" produit, pas d'image réseau nécessaire
  final double rating;
  final int stock;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.emoji,
    required this.rating,
    required this.stock,
  });
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);
}

enum SortOption { nameAsc, priceAsc, priceDesc, ratingDesc }

extension SortOptionLabel on SortOption {
  String get label => switch (this) {
        SortOption.nameAsc => 'Nom (A-Z)',
        SortOption.priceAsc => 'Prix croissant',
        SortOption.priceDesc => 'Prix décroissant',
        SortOption.ratingDesc => 'Meilleures notes',
      };
}

@immutable
class ProductFilter {
  final String? category; // null = toutes catégories
  final String searchQuery;
  final SortOption sortOption;

  const ProductFilter({
    this.category,
    this.searchQuery = '',
    this.sortOption = SortOption.nameAsc,
  });

  ProductFilter copyWith({
    String? category,
    bool clearCategory = false,
    String? searchQuery,
    SortOption? sortOption,
  }) {
    return ProductFilter(
      category: clearCategory ? null : (category ?? this.category),
      searchQuery: searchQuery ?? this.searchQuery,
      sortOption: sortOption ?? this.sortOption,
    );
  }
}

class UserProfile {
  final String name;
  final String email;
  final String memberSince;
  final int ordersCount;

  const UserProfile({
    required this.name,
    required this.email,
    required this.memberSince,
    required this.ordersCount,
  });
}

// ============================================================================
// 2. DATA LAYER (repository) — mock d'une source de données / API
// ============================================================================

final List<Product> _mockCatalog = [
  const Product(id: 1, name: 'Casque Audio Pro', description: 'Casque sans fil à réduction de bruit active, autonomie 30h.', price: 89.99, category: 'Audio', emoji: '🎧', rating: 4.6, stock: 12),
  const Product(id: 2, name: 'Enceinte Bluetooth', description: 'Enceinte portable étanche, son 360°.', price: 39.90, category: 'Audio', emoji: '🔊', rating: 4.2, stock: 20),
  const Product(id: 3, name: 'Montre Connectée', description: 'Suivi sport et sommeil, écran AMOLED.', price: 129.00, category: 'Wearable', emoji: '⌚', rating: 4.4, stock: 8),
  const Product(id: 4, name: 'Bracelet Fitness', description: 'Suivi d\'activité léger, autonomie 10 jours.', price: 24.99, category: 'Wearable', emoji: '📿', rating: 3.9, stock: 30),
  const Product(id: 5, name: 'Clavier Mécanique', description: 'Switches rouges, rétroéclairage RGB.', price: 74.50, category: 'Informatique', emoji: '⌨️', rating: 4.7, stock: 15),
  const Product(id: 6, name: 'Souris Sans Fil', description: 'Ergonomique, capteur haute précision.', price: 29.99, category: 'Informatique', emoji: '🖱️', rating: 4.1, stock: 25),
  const Product(id: 7, name: 'Sac à Dos Urbain', description: 'Compartiment laptop 15", résistant à l\'eau.', price: 54.90, category: 'Accessoires', emoji: '🎒', rating: 4.3, stock: 18),
  const Product(id: 8, name: 'Batterie Externe 20000mAh', description: 'Charge rapide, 2 ports USB-C.', price: 34.90, category: 'Accessoires', emoji: '🔋', rating: 4.5, stock: 22),
  const Product(id: 9, name: 'Lampe de Bureau LED', description: 'Luminosité réglable, port USB intégré.', price: 22.00, category: 'Maison', emoji: '💡', rating: 4.0, stock: 14),
  const Product(id: 10, name: 'Cafetière Programmable', description: 'Prépare le café à l\'heure souhaitée.', price: 45.00, category: 'Maison', emoji: '☕', rating: 4.4, stock: 9),
  const Product(id: 11, name: 'Webcam Full HD', description: '1080p, micro intégré, autofocus.', price: 42.00, category: 'Informatique', emoji: '📷', rating: 4.2, stock: 11),
  const Product(id: 12, name: 'Support Téléphone', description: 'Réglable, compatible tous smartphones.', price: 12.90, category: 'Accessoires', emoji: '📱', rating: 3.8, stock: 40),
];

class ProductRepository {
  /// Simule un appel réseau. [simulateError] permet de démontrer la gestion
  /// d'erreur dans l'UI (voir écran Profil -> "Simuler une erreur réseau").
  Future<List<Product>> fetchProducts({bool simulateError = false}) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (simulateError) {
      throw Exception('Impossible de charger le catalogue (erreur réseau simulée).');
    }
    return _mockCatalog;
  }

  Future<UserProfile> fetchUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const UserProfile(
      name: 'Aïcha Traoré',
      email: 'aicha.traore@example.com',
      memberSince: 'Mars 2024',
      ordersCount: 7,
    );
  }
}

// ============================================================================
// 3. PROVIDERS — toute la logique métier vit ici, jamais dans les widgets
// ============================================================================

/// Provider #1 — expose le repository (couche data) au reste de l'app.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// Provider #2 — StateProvider simple : active/désactive la simulation
/// d'erreur réseau (utilisé pour démontrer AsyncValue.error dans l'UI).
final simulateErrorProvider = StateProvider<bool>((ref) => false);

/// Provider #3 — FutureProvider : charge le catalogue de façon asynchrone.
/// Exposé sous forme d'AsyncValue<List<Product>> (loading / data / error).
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final simulateError = ref.watch(simulateErrorProvider);
  return repo.fetchProducts(simulateError: simulateError);
});

/// StateNotifier #1 — gère l'état du filtre / tri courant.
class ProductFilterNotifier extends StateNotifier<ProductFilter> {
  ProductFilterNotifier() : super(const ProductFilter());

  void setCategory(String? category) {
    state = state.copyWith(category: category, clearCategory: category == null);
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void setSortOption(SortOption option) => state = state.copyWith(sortOption: option);
}

/// Provider #4 — expose ProductFilterNotifier.
final productFilterProvider =
    StateNotifierProvider<ProductFilterNotifier, ProductFilter>((ref) {
  return ProductFilterNotifier();
});

/// Provider #5 — Provider dérivé : combine productsProvider + productFilterProvider
/// pour produire la liste filtrée/triée, tout en conservant l'AsyncValue
/// (loading/error se propagent automatiquement grâce à `.whenData`).
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final filter = ref.watch(productFilterProvider);

  return productsAsync.whenData((products) {
    var result = products.where((p) {
      final matchesCategory = filter.category == null || p.category == filter.category;
      final matchesSearch = filter.searchQuery.isEmpty ||
          p.name.toLowerCase().contains(filter.searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    switch (filter.sortOption) {
      case SortOption.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.priceAsc:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.ratingDesc:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return result;
  });
});

/// Provider dérivé simple : liste des catégories disponibles (pour les chips).
final categoriesProvider = Provider<List<String>>((ref) {
  return _mockCatalog.map((p) => p.category).toSet().toList()..sort();
});

/// StateNotifier #2 — gère le panier d'achat.
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addProduct(Product product) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      final updated = [...state];
      updated[index] = updated[index].copyWith(quantity: updated[index].quantity + 1);
      state = updated;
    } else {
      state = [...state, CartItem(product: product, quantity: 1)];
    }
  }

  void removeProduct(int productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void setQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    state = [
      for (final item in state)
        if (item.product.id == productId) item.copyWith(quantity: quantity) else item,
    ];
  }

  void clear() => state = [];
}

/// Provider #6 — expose CartNotifier.
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

/// Providers dérivés du panier — recalculés automatiquement à chaque changement.
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold(0.0, (sum, item) => sum + item.subtotal);
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(0, (sum, item) => sum + item.quantity);
});

/// StateNotifier #3 — gère les favoris, persistés localement via SharedPreferences.
class FavoritesNotifier extends StateNotifier<Set<int>> {
  static const _prefsKey = 'favorite_product_ids';

  FavoritesNotifier() : super(<int>{}) {
    _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    state = saved.map(int.parse).toSet();
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state.map((id) => id.toString()).toList());
  }

  Future<void> toggle(int productId) async {
    final updated = {...state};
    if (updated.contains(productId)) {
      updated.remove(productId);
    } else {
      updated.add(productId);
    }
    state = updated;
    await _saveToDisk();
  }

  bool isFavorite(int productId) => state.contains(productId);
}

/// Provider #7 — expose FavoritesNotifier (état persisté localement).
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<int>>((ref) {
  return FavoritesNotifier();
});

/// Provider dérivé : produits favoris, en conservant l'AsyncValue du catalogue.
final favoriteProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final favoriteIds = ref.watch(favoritesProvider);
  return productsAsync.whenData(
    (products) => products.where((p) => favoriteIds.contains(p.id)).toList(),
  );
});

/// Provider #8 — FutureProvider : profil utilisateur mocké.
final userProfileProvider = FutureProvider<UserProfile>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return repo.fetchUserProfile();
});

// ============================================================================
// 4. UI LAYER
// ============================================================================

class ECommerceApp extends StatelessWidget {
  const ECommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Commerce Riverpod',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B5BFD),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tabIndex = 0;

  static const _screens = [
    ProductListScreen(),
    FavoritesScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Catalogue'),
          const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoris'),
          NavigationDestination(icon: const _CartIcon(), selectedIcon: const _CartIcon(selected: true), label: 'Panier'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Icône du panier avec badge animé (BONUS animation) : le badge "pulse"
/// à chaque ajout d'article, via ref.listen sur cartItemCountProvider.
class _CartIcon extends ConsumerStatefulWidget {
  final bool selected;
  const _CartIcon({this.selected = false});

  @override
  ConsumerState<_CartIcon> createState() => _CartIconState();
}

class _CartIconState extends ConsumerState<_CartIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    lowerBound: 1.0,
    upperBound: 1.4,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(cartItemCountProvider, (previous, next) {
      if (previous != null && next > previous) {
        _controller.forward(from: 1.0).then((_) => _controller.reverse());
      }
    });

    final count = ref.watch(cartItemCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.selected ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (count > 0)
          Positioned(
            right: -8,
            top: -6,
            child: ScaleTransition(
              scale: _controller,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Écran Catalogue (liste + filtres + tri)
// ---------------------------------------------------------------------------

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredProductsProvider);
    final categories = ref.watch(categoriesProvider);
    final filter = ref.watch(productFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un produit…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (value) => ref.read(productFilterProvider.notifier).setSearchQuery(value),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _CategoryChip(
                  label: 'Toutes',
                  selected: filter.category == null,
                  onTap: () => ref.read(productFilterProvider.notifier).setCategory(null),
                ),
                for (final category in categories)
                  _CategoryChip(
                    label: category,
                    selected: filter.category == category,
                    onTap: () => ref.read(productFilterProvider.notifier).setCategory(category),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trier par :', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<SortOption>(
                  value: filter.sortOption,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final option in SortOption.values)
                      DropdownMenuItem(value: option, child: Text(option.label)),
                  ],
                  onChanged: (option) {
                    if (option != null) ref.read(productFilterProvider.notifier).setSortOption(option);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorRetry(
                message: error.toString(),
                onRetry: () => ref.invalidate(productsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const Center(child: Text('Aucun produit ne correspond à votre recherche.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _ProductCard(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(product.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Center(child: Text(product.emoji, style: const TextStyle(fontSize: 48))),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.redAccent : null),
                        onPressed: () => ref.read(favoritesProvider.notifier).toggle(product.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${product.price.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    onPressed: () => _addToCart(context, ref, product),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _addToCart(BuildContext context, WidgetRef ref, Product product) {
  ref.read(cartProvider.notifier).addProduct(product);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${product.name} ajouté au panier'), duration: const Duration(milliseconds: 900)),
  );
}

// ---------------------------------------------------------------------------
// Écran Détail produit
// ---------------------------------------------------------------------------

class ProductDetailScreen extends ConsumerWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final isFavorite = ref.watch(favoritesProvider).contains(productId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail produit'),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.redAccent : null),
            onPressed: () => ref.read(favoritesProvider.notifier).toggle(productId),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorRetry(message: error.toString(), onRetry: () => ref.invalidate(productsProvider)),
        data: (products) {
          final product = products.firstWhere((p) => p.id == productId);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text(product.emoji, style: const TextStyle(fontSize: 100))),
                const SizedBox(height: 20),
                Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Chip(label: Text(product.category)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text('${product.rating} · ${product.stock} en stock'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(product.description, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                Text('${product.price.toStringAsFixed(2)} €', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Ajouter au panier'),
                    onPressed: () => _addToCart(context, ref, product),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran Favoris
// ---------------------------------------------------------------------------

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes favoris')),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorRetry(message: error.toString(), onRetry: () => ref.invalidate(productsProvider)),
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('Aucun favori pour le moment.\nAppuyez sur ♥ sur un produit pour l\'ajouter.', textAlign: TextAlign.center));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: Text(product.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(product.name),
                subtitle: Text('${product.price.toStringAsFixed(2)} €'),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.redAccent),
                  onPressed: () => ref.read(favoritesProvider.notifier).toggle(product.id),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran Panier
// ---------------------------------------------------------------------------

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              tooltip: 'Vider le panier',
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Votre panier est vide.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cartItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  leading: Text(item.product.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(item.product.name),
                  subtitle: Text('${item.product.price.toStringAsFixed(2)} € × ${item.quantity} = ${item.subtotal.toStringAsFixed(2)} €'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => ref.read(cartProvider.notifier).setQuantity(item.product.id, item.quantity - 1),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => ref.read(cartProvider.notifier).setQuantity(item.product.id, item.quantity + 1),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Total : ${total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Commande validée (mock) — merci !')),
                        );
                      },
                      child: const Text('Commander'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran Profil (mock)
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final simulateError = ref.watch(simulateErrorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorRetry(message: error.toString(), onRetry: () => ref.invalidate(userProfileProvider)),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CircleAvatar(radius: 40, child: Text(profile.name.substring(0, 1))),
            const SizedBox(height: 16),
            Center(child: Text(profile.name, style: Theme.of(context).textTheme.titleLarge)),
            Center(child: Text(profile.email, style: Theme.of(context).textTheme.bodyMedium)),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.calendar_today), title: const Text('Membre depuis'), trailing: Text(profile.memberSince)),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Commandes passées'), trailing: Text('${profile.ordersCount}')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Simuler une erreur réseau'),
              subtitle: const Text('Force le catalogue à échouer, pour démontrer la gestion d\'erreur (AsyncValue.error).'),
              value: simulateError,
              onChanged: (value) {
                ref.read(simulateErrorProvider.notifier).state = value;
                ref.invalidate(productsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

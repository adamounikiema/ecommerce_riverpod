# E-Commerce Riverpod Demo

Application Flutter e-commerce construite pour valider la maîtrise du
state management avec **Riverpod** (`flutter_riverpod`).

## Fonctionnalités

- Catalogue de produits (grille + écran de détail)
- Panier d'achat (ajout, suppression, modification de quantité, total, "commander")
- Favoris persistés localement avec `shared_preferences`
- Filtrage par catégorie + recherche texte, et tri (nom, prix, note)
- Écran de profil utilisateur (mock, chargé de façon asynchrone)
- Bonus : badge du panier animé (pulse) à chaque ajout, via `ref.listen` + `AnimationController`

## Lancer le projet

```bash
flutter pub get
flutter run
```

Aucune dépendance réseau réelle : les données sont mockées dans
`ProductRepository` (délai artificiel pour simuler un appel API).

## Architecture en couches

```
lib/main.dart
├── 1. MODELS        → Product, CartItem, ProductFilter, UserProfile, SortOption
├── 2. DATA LAYER    → ProductRepository (accès aux données, mocké)
├── 3. PROVIDERS     → toute la logique métier (aucune logique dans les widgets)
└── 4. UI LAYER      → écrans et widgets, ne font que lire/écrire les providers
```

Le fichier est volontairement livré en un seul module exécutable pour la
démonstration, mais les sections sont clairement séparées et pourraient être
éclatées en `models/`, `data/`, `providers/`, `screens/` sans changer la logique.

## Providers utilisés

| # | Provider | Type | Rôle |
|---|----------|------|------|
| 1 | `productRepositoryProvider` | `Provider` | Expose la couche data à l'app |
| 2 | `simulateErrorProvider` | `StateProvider<bool>` | Active une erreur réseau simulée (démo du chemin d'erreur) |
| 3 | `productsProvider` | `FutureProvider<List<Product>>` | Charge le catalogue, exposé en `AsyncValue` (loading/data/error) |
| 4 | `productFilterProvider` | `StateNotifierProvider<ProductFilterNotifier, ProductFilter>` | État du filtre (catégorie, recherche, tri) |
| 5 | `filteredProductsProvider` | `Provider<AsyncValue<List<Product>>>` | Dérive `productsProvider` + `productFilterProvider` → liste filtrée/triée |
| 6 | `cartProvider` | `StateNotifierProvider<CartNotifier, List<CartItem>>` | Gère l'ajout/suppression/quantité du panier |
| 7 | `cartTotalProvider` / `cartItemCountProvider` | `Provider` | Dérivés du panier (total €, nombre d'articles) |
| 8 | `favoritesProvider` | `StateNotifierProvider<FavoritesNotifier, Set<int>>` | Favoris, persistés via `SharedPreferences` |
| 9 | `favoriteProductsProvider` | `Provider<AsyncValue<List<Product>>>` | Dérive catalogue + favoris → liste des produits favoris |
| 10 | `userProfileProvider` | `FutureProvider<UserProfile>` | Charge le profil mocké de façon asynchrone |
| — | `categoriesProvider` | `Provider<List<String>>` | Liste des catégories pour les chips de filtre |

Cela dépasse largement l'exigence minimale de 5 providers distincts, tout en
gardant chaque provider responsable d'une seule chose (principe de
séparation des responsabilités).

## Gestion des états asynchrones

Tous les flux asynchrones (`productsProvider`, `filteredProductsProvider`,
`favoriteProductsProvider`, `userProfileProvider`) sont exposés en
`AsyncValue<T>` et consommés via `.when(loading:, error:, data:)` dans l'UI :

- **loading** → `CircularProgressIndicator`
- **error** → widget `_ErrorRetry` avec message + bouton "Réessayer" qui fait
  `ref.invalidate(...)` pour relancer le `FutureProvider`
- **data** → rendu normal

Pour tester le chemin d'erreur : Profil → activer "Simuler une erreur réseau".

## Persistance

Les favoris sont sauvegardés sous forme de liste d'identifiants dans
`SharedPreferences` (clé `favorite_product_ids`), rechargés automatiquement
au démarrage de `FavoritesNotifier`.

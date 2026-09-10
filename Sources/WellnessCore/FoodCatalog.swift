import Foundation

public enum FoodCategory: String, CaseIterable, Codable, Sendable {
    case protein, dairy, grains, fruit, vegetables, legumes, nutsSeeds, fats, snacks, drinks

    public var label: String {
        switch self {
        case .protein: return "Meat, fish & eggs"
        case .dairy: return "Dairy"
        case .grains: return "Grains & bread"
        case .fruit: return "Fruit"
        case .vegetables: return "Vegetables"
        case .legumes: return "Beans & legumes"
        case .nutsSeeds: return "Nuts & seeds"
        case .fats: return "Oils & fats"
        case .snacks: return "Snacks & sweets"
        case .drinks: return "Drinks"
        }
    }
}

/// A staple food with nutrition per 100 g and a typical serving.
public struct FoodDefinition: Hashable, Sendable {
    public let name: String
    public let category: FoodCategory
    public let per100: Macro
    public let servingGrams: Double
    public let servingLabel: String

    public init(name: String, category: FoodCategory, per100: Macro, servingGrams: Double, servingLabel: String) {
        self.name = name; self.category = category; self.per100 = per100; self.servingGrams = servingGrams; self.servingLabel = servingLabel
    }
}

/// Built-in staples: whole foods and common items that have no barcode.
///
/// Values are typical figures per 100 g (USDA-style, rounded); packaged
/// products should come from a barcode scan, which reads the actual label.
/// Like the exercise catalog this is code, not schema: entries are seeded into
/// the food list by name on launch and never overwrite a food the user edited.
public enum FoodCatalog {
    private static func f(_ name: String, _ category: FoodCategory, kcal: Double, p: Double, c: Double, fat: Double,
                          serving: Double, _ servingLabel: String) -> FoodDefinition {
        FoodDefinition(name: name, category: category, per100: Macro(calories: kcal, protein: p, carbs: c, fat: fat),
                       servingGrams: serving, servingLabel: servingLabel)
    }

    static let protein: [FoodDefinition] = [
        f("Chicken Breast, cooked", .protein, kcal: 165, p: 31, c: 0, fat: 3.6, serving: 120, "1 breast"),
        f("Chicken Thigh, cooked", .protein, kcal: 209, p: 26, c: 0, fat: 11, serving: 100, "1 thigh"),
        f("Ground Turkey 93/7, cooked", .protein, kcal: 176, p: 27, c: 0, fat: 7, serving: 112, "4 oz"),
        f("Ground Beef 90/10, cooked", .protein, kcal: 217, p: 27, c: 0, fat: 12, serving: 112, "4 oz"),
        f("Ground Beef 80/20, cooked", .protein, kcal: 254, p: 26, c: 0, fat: 16, serving: 112, "4 oz"),
        f("Sirloin Steak, cooked", .protein, kcal: 206, p: 29, c: 0, fat: 9, serving: 150, "1 steak"),
        f("Pork Tenderloin, cooked", .protein, kcal: 143, p: 26, c: 0, fat: 3.5, serving: 120, "4 oz"),
        f("Pork Chop, cooked", .protein, kcal: 231, p: 26, c: 0, fat: 14, serving: 130, "1 chop"),
        f("Bacon, cooked", .protein, kcal: 541, p: 37, c: 1.4, fat: 42, serving: 16, "2 slices"),
        f("Salmon, cooked", .protein, kcal: 208, p: 20, c: 0, fat: 13, serving: 140, "1 fillet"),
        f("Tuna, canned in water", .protein, kcal: 116, p: 26, c: 0, fat: 1, serving: 100, "1 can, drained"),
        f("Cod, cooked", .protein, kcal: 105, p: 23, c: 0, fat: 0.9, serving: 140, "1 fillet"),
        f("Shrimp, cooked", .protein, kcal: 99, p: 24, c: 0.2, fat: 0.3, serving: 100, "~10 large"),
        f("Tilapia, cooked", .protein, kcal: 128, p: 26, c: 0, fat: 2.7, serving: 120, "1 fillet"),
        f("Egg, whole", .protein, kcal: 155, p: 13, c: 1.1, fat: 11, serving: 50, "1 large"),
        f("Egg White", .protein, kcal: 52, p: 11, c: 0.7, fat: 0.2, serving: 33, "1 large"),
        f("Tofu, firm", .protein, kcal: 144, p: 17, c: 2.8, fat: 8.7, serving: 100, "1/3 block"),
        f("Tempeh", .protein, kcal: 192, p: 20, c: 8, fat: 11, serving: 100, "1/2 package"),
        f("Deli Turkey Breast", .protein, kcal: 104, p: 17, c: 4, fat: 2, serving: 56, "2 oz"),
        f("Whey Protein Powder", .protein, kcal: 380, p: 75, c: 8, fat: 5, serving: 32, "1 scoop"),
        f("Plant Protein Powder", .protein, kcal: 370, p: 65, c: 12, fat: 6, serving: 35, "1 scoop"),
    ]

    static let dairy: [FoodDefinition] = [
        f("Greek Yogurt, nonfat", .dairy, kcal: 59, p: 10, c: 3.6, fat: 0.4, serving: 170, "1 cup"),
        f("Greek Yogurt, 2%", .dairy, kcal: 73, p: 9.9, c: 3.9, fat: 1.9, serving: 170, "1 cup"),
        f("Greek Yogurt, whole", .dairy, kcal: 97, p: 9, c: 4, fat: 5, serving: 170, "1 cup"),
        f("Cottage Cheese, 2%", .dairy, kcal: 84, p: 11, c: 4.3, fat: 2.3, serving: 113, "1/2 cup"),
        f("Skyr", .dairy, kcal: 63, p: 11, c: 4, fat: 0.2, serving: 170, "1 cup"),
        f("Milk, whole", .dairy, kcal: 61, p: 3.2, c: 4.8, fat: 3.3, serving: 244, "1 cup"),
        f("Milk, 2%", .dairy, kcal: 50, p: 3.3, c: 4.8, fat: 2, serving: 244, "1 cup"),
        f("Milk, skim", .dairy, kcal: 34, p: 3.4, c: 5, fat: 0.1, serving: 244, "1 cup"),
        f("Cheddar Cheese", .dairy, kcal: 403, p: 25, c: 1.3, fat: 33, serving: 28, "1 oz"),
        f("Mozzarella, part-skim", .dairy, kcal: 254, p: 24, c: 3, fat: 16, serving: 28, "1 oz"),
        f("Feta Cheese", .dairy, kcal: 264, p: 14, c: 4, fat: 21, serving: 28, "1 oz"),
        f("Parmesan Cheese", .dairy, kcal: 431, p: 38, c: 4, fat: 29, serving: 10, "1 tbsp"),
        f("Cream Cheese", .dairy, kcal: 342, p: 6, c: 4, fat: 34, serving: 28, "2 tbsp"),
        f("Butter", .dairy, kcal: 717, p: 0.9, c: 0.1, fat: 81, serving: 14, "1 tbsp"),
        f("String Cheese", .dairy, kcal: 280, p: 25, c: 2, fat: 20, serving: 28, "1 stick"),
    ]

    static let grains: [FoodDefinition] = [
        f("White Rice, cooked", .grains, kcal: 130, p: 2.7, c: 28, fat: 0.3, serving: 158, "1 cup"),
        f("Brown Rice, cooked", .grains, kcal: 112, p: 2.3, c: 24, fat: 0.8, serving: 195, "1 cup"),
        f("Jasmine Rice, cooked", .grains, kcal: 130, p: 2.7, c: 28, fat: 0.3, serving: 158, "1 cup"),
        f("Quinoa, cooked", .grains, kcal: 120, p: 4.4, c: 21, fat: 1.9, serving: 185, "1 cup"),
        f("Oats, dry", .grains, kcal: 389, p: 17, c: 66, fat: 6.9, serving: 40, "1/2 cup"),
        f("Oatmeal, cooked with water", .grains, kcal: 71, p: 2.5, c: 12, fat: 1.5, serving: 234, "1 cup"),
        f("Pasta, cooked", .grains, kcal: 158, p: 5.8, c: 31, fat: 0.9, serving: 140, "1 cup"),
        f("Whole Wheat Pasta, cooked", .grains, kcal: 124, p: 5.3, c: 27, fat: 0.5, serving: 140, "1 cup"),
        f("Bread, white", .grains, kcal: 265, p: 9, c: 49, fat: 3.2, serving: 28, "1 slice"),
        f("Bread, whole wheat", .grains, kcal: 247, p: 13, c: 41, fat: 3.4, serving: 32, "1 slice"),
        f("Sourdough Bread", .grains, kcal: 274, p: 11, c: 52, fat: 2, serving: 50, "1 slice"),
        f("Bagel, plain", .grains, kcal: 250, p: 10, c: 49, fat: 1.5, serving: 100, "1 bagel"),
        f("Flour Tortilla", .grains, kcal: 312, p: 8, c: 51, fat: 8, serving: 45, "1 medium"),
        f("Corn Tortilla", .grains, kcal: 218, p: 5.7, c: 45, fat: 2.9, serving: 26, "1 tortilla"),
        f("Potato, baked", .grains, kcal: 93, p: 2.5, c: 21, fat: 0.1, serving: 173, "1 medium"),
        f("Sweet Potato, baked", .grains, kcal: 90, p: 2, c: 21, fat: 0.2, serving: 150, "1 medium"),
        f("Couscous, cooked", .grains, kcal: 112, p: 3.8, c: 23, fat: 0.2, serving: 157, "1 cup"),
        f("Granola", .grains, kcal: 471, p: 10, c: 64, fat: 20, serving: 50, "1/2 cup"),
        f("Cereal, corn flakes", .grains, kcal: 357, p: 7.5, c: 84, fat: 0.4, serving: 30, "1 cup"),
        f("Rice Cake", .grains, kcal: 387, p: 8, c: 82, fat: 2.8, serving: 9, "1 cake"),
        f("Cream of Rice, dry", .grains, kcal: 370, p: 6, c: 82, fat: 0.5, serving: 45, "1/4 cup"),
    ]

    static let fruit: [FoodDefinition] = [
        f("Banana", .fruit, kcal: 89, p: 1.1, c: 23, fat: 0.3, serving: 118, "1 medium"),
        f("Apple", .fruit, kcal: 52, p: 0.3, c: 14, fat: 0.2, serving: 182, "1 medium"),
        f("Blueberries", .fruit, kcal: 57, p: 0.7, c: 14, fat: 0.3, serving: 148, "1 cup"),
        f("Strawberries", .fruit, kcal: 32, p: 0.7, c: 7.7, fat: 0.3, serving: 152, "1 cup"),
        f("Raspberries", .fruit, kcal: 52, p: 1.2, c: 12, fat: 0.7, serving: 123, "1 cup"),
        f("Orange", .fruit, kcal: 47, p: 0.9, c: 12, fat: 0.1, serving: 131, "1 medium"),
        f("Grapes", .fruit, kcal: 69, p: 0.7, c: 18, fat: 0.2, serving: 151, "1 cup"),
        f("Mango", .fruit, kcal: 60, p: 0.8, c: 15, fat: 0.4, serving: 165, "1 cup"),
        f("Pineapple", .fruit, kcal: 50, p: 0.5, c: 13, fat: 0.1, serving: 165, "1 cup"),
        f("Watermelon", .fruit, kcal: 30, p: 0.6, c: 7.6, fat: 0.2, serving: 152, "1 cup"),
        f("Avocado", .fruit, kcal: 160, p: 2, c: 8.5, fat: 15, serving: 68, "1/2 avocado"),
        f("Peach", .fruit, kcal: 39, p: 0.9, c: 9.5, fat: 0.3, serving: 150, "1 medium"),
        f("Pear", .fruit, kcal: 57, p: 0.4, c: 15, fat: 0.1, serving: 178, "1 medium"),
        f("Cherries", .fruit, kcal: 63, p: 1.1, c: 16, fat: 0.2, serving: 138, "1 cup"),
        f("Kiwi", .fruit, kcal: 61, p: 1.1, c: 15, fat: 0.5, serving: 69, "1 fruit"),
        f("Dates, Medjool", .fruit, kcal: 277, p: 1.8, c: 75, fat: 0.2, serving: 24, "1 date"),
        f("Raisins", .fruit, kcal: 299, p: 3.1, c: 79, fat: 0.5, serving: 40, "small box"),
    ]

    static let vegetables: [FoodDefinition] = [
        f("Broccoli, cooked", .vegetables, kcal: 35, p: 2.4, c: 7.2, fat: 0.4, serving: 156, "1 cup"),
        f("Spinach, raw", .vegetables, kcal: 23, p: 2.9, c: 3.6, fat: 0.4, serving: 30, "1 cup"),
        f("Kale, raw", .vegetables, kcal: 49, p: 4.3, c: 8.8, fat: 0.9, serving: 67, "1 cup"),
        f("Mixed Salad Greens", .vegetables, kcal: 17, p: 1.5, c: 3, fat: 0.2, serving: 85, "3 cups"),
        f("Carrot", .vegetables, kcal: 41, p: 0.9, c: 9.6, fat: 0.2, serving: 61, "1 medium"),
        f("Bell Pepper", .vegetables, kcal: 31, p: 1, c: 6, fat: 0.3, serving: 119, "1 medium"),
        f("Cucumber", .vegetables, kcal: 15, p: 0.7, c: 3.6, fat: 0.1, serving: 104, "1 cup"),
        f("Tomato", .vegetables, kcal: 18, p: 0.9, c: 3.9, fat: 0.2, serving: 123, "1 medium"),
        f("Cherry Tomatoes", .vegetables, kcal: 18, p: 0.9, c: 3.9, fat: 0.2, serving: 149, "1 cup"),
        f("Onion", .vegetables, kcal: 40, p: 1.1, c: 9.3, fat: 0.1, serving: 110, "1 medium"),
        f("Zucchini, cooked", .vegetables, kcal: 15, p: 1.1, c: 2.7, fat: 0.4, serving: 180, "1 cup"),
        f("Asparagus, cooked", .vegetables, kcal: 22, p: 2.4, c: 4.1, fat: 0.2, serving: 180, "1 cup"),
        f("Green Beans, cooked", .vegetables, kcal: 35, p: 1.9, c: 7.9, fat: 0.3, serving: 125, "1 cup"),
        f("Cauliflower, cooked", .vegetables, kcal: 23, p: 1.8, c: 4.1, fat: 0.5, serving: 124, "1 cup"),
        f("Brussels Sprouts, cooked", .vegetables, kcal: 36, p: 2.6, c: 7.1, fat: 0.5, serving: 155, "1 cup"),
        f("Mushrooms, raw", .vegetables, kcal: 22, p: 3.1, c: 3.3, fat: 0.3, serving: 70, "1 cup"),
        f("Corn, cooked", .vegetables, kcal: 96, p: 3.4, c: 21, fat: 1.5, serving: 154, "1 cup"),
        f("Peas, cooked", .vegetables, kcal: 84, p: 5.4, c: 16, fat: 0.2, serving: 160, "1 cup"),
        f("Edamame, shelled", .vegetables, kcal: 121, p: 12, c: 9, fat: 5, serving: 155, "1 cup"),
        f("Butternut Squash, cooked", .vegetables, kcal: 40, p: 0.9, c: 10, fat: 0.1, serving: 205, "1 cup"),
    ]

    static let legumes: [FoodDefinition] = [
        f("Black Beans, cooked", .legumes, kcal: 132, p: 8.9, c: 24, fat: 0.5, serving: 172, "1 cup"),
        f("Chickpeas, cooked", .legumes, kcal: 164, p: 8.9, c: 27, fat: 2.6, serving: 164, "1 cup"),
        f("Lentils, cooked", .legumes, kcal: 116, p: 9, c: 20, fat: 0.4, serving: 198, "1 cup"),
        f("Kidney Beans, cooked", .legumes, kcal: 127, p: 8.7, c: 23, fat: 0.5, serving: 177, "1 cup"),
        f("Pinto Beans, cooked", .legumes, kcal: 143, p: 9, c: 26, fat: 0.6, serving: 171, "1 cup"),
        f("Hummus", .legumes, kcal: 166, p: 7.9, c: 14, fat: 9.6, serving: 30, "2 tbsp"),
        f("Refried Beans", .legumes, kcal: 91, p: 5.4, c: 15, fat: 1.2, serving: 120, "1/2 cup"),
    ]

    static let nutsSeeds: [FoodDefinition] = [
        f("Almonds", .nutsSeeds, kcal: 579, p: 21, c: 22, fat: 50, serving: 28, "1 oz (~23)"),
        f("Walnuts", .nutsSeeds, kcal: 654, p: 15, c: 14, fat: 65, serving: 28, "1 oz"),
        f("Cashews", .nutsSeeds, kcal: 553, p: 18, c: 30, fat: 44, serving: 28, "1 oz"),
        f("Pistachios", .nutsSeeds, kcal: 560, p: 20, c: 28, fat: 45, serving: 28, "1 oz"),
        f("Peanuts", .nutsSeeds, kcal: 567, p: 26, c: 16, fat: 49, serving: 28, "1 oz"),
        f("Peanut Butter", .nutsSeeds, kcal: 588, p: 25, c: 20, fat: 50, serving: 32, "2 tbsp"),
        f("Almond Butter", .nutsSeeds, kcal: 614, p: 21, c: 19, fat: 56, serving: 32, "2 tbsp"),
        f("Chia Seeds", .nutsSeeds, kcal: 486, p: 17, c: 42, fat: 31, serving: 28, "2 tbsp"),
        f("Flax Seeds, ground", .nutsSeeds, kcal: 534, p: 18, c: 29, fat: 42, serving: 14, "2 tbsp"),
        f("Pumpkin Seeds", .nutsSeeds, kcal: 559, p: 30, c: 11, fat: 49, serving: 28, "1 oz"),
        f("Sunflower Seeds", .nutsSeeds, kcal: 584, p: 21, c: 20, fat: 51, serving: 28, "1 oz"),
    ]

    static let fats: [FoodDefinition] = [
        f("Olive Oil", .fats, kcal: 884, p: 0, c: 0, fat: 100, serving: 14, "1 tbsp"),
        f("Coconut Oil", .fats, kcal: 892, p: 0, c: 0, fat: 99, serving: 14, "1 tbsp"),
        f("Avocado Oil", .fats, kcal: 884, p: 0, c: 0, fat: 100, serving: 14, "1 tbsp"),
        f("Mayonnaise", .fats, kcal: 680, p: 1, c: 0.6, fat: 75, serving: 14, "1 tbsp"),
        f("Ranch Dressing", .fats, kcal: 430, p: 1.3, c: 6, fat: 45, serving: 30, "2 tbsp"),
        f("Heavy Cream", .fats, kcal: 340, p: 2.8, c: 2.8, fat: 36, serving: 15, "1 tbsp"),
    ]

    static let snacks: [FoodDefinition] = [
        f("Dark Chocolate, 70%", .snacks, kcal: 598, p: 7.8, c: 46, fat: 43, serving: 28, "1 oz"),
        f("Milk Chocolate", .snacks, kcal: 535, p: 7.7, c: 59, fat: 30, serving: 43, "1 bar"),
        f("Potato Chips", .snacks, kcal: 536, p: 7, c: 53, fat: 35, serving: 28, "1 oz"),
        f("Tortilla Chips", .snacks, kcal: 489, p: 7, c: 63, fat: 24, serving: 28, "1 oz"),
        f("Popcorn, air-popped", .snacks, kcal: 387, p: 13, c: 78, fat: 4.5, serving: 24, "3 cups"),
        f("Pretzels", .snacks, kcal: 380, p: 10, c: 80, fat: 3, serving: 28, "1 oz"),
        f("Crackers, saltine", .snacks, kcal: 421, p: 9, c: 74, fat: 9, serving: 15, "5 crackers"),
        f("Chocolate Chip Cookie", .snacks, kcal: 488, p: 5, c: 65, fat: 24, serving: 30, "1 cookie"),
        f("Ice Cream, vanilla", .snacks, kcal: 207, p: 3.5, c: 24, fat: 11, serving: 66, "1/2 cup"),
        f("Honey", .snacks, kcal: 304, p: 0.3, c: 82, fat: 0, serving: 21, "1 tbsp"),
        f("Maple Syrup", .snacks, kcal: 260, p: 0, c: 67, fat: 0.1, serving: 20, "1 tbsp"),
        f("Sugar", .snacks, kcal: 387, p: 0, c: 100, fat: 0, serving: 4, "1 tsp"),
        f("Jam", .snacks, kcal: 278, p: 0.4, c: 69, fat: 0.1, serving: 20, "1 tbsp"),
        f("Protein Bar", .snacks, kcal: 400, p: 33, c: 40, fat: 13, serving: 60, "1 bar"),
    ]

    static let drinks: [FoodDefinition] = [
        f("Orange Juice", .drinks, kcal: 45, p: 0.7, c: 10, fat: 0.2, serving: 248, "1 cup"),
        f("Apple Juice", .drinks, kcal: 46, p: 0.1, c: 11, fat: 0.1, serving: 248, "1 cup"),
        f("Coca-Cola", .drinks, kcal: 42, p: 0, c: 11, fat: 0, serving: 355, "1 can"),
        f("Oat Milk", .drinks, kcal: 47, p: 1, c: 7, fat: 1.5, serving: 240, "1 cup"),
        f("Almond Milk, unsweetened", .drinks, kcal: 15, p: 0.6, c: 0.6, fat: 1.2, serving: 240, "1 cup"),
        f("Soy Milk", .drinks, kcal: 43, p: 3.3, c: 4.9, fat: 1.9, serving: 240, "1 cup"),
        f("Latte, whole milk", .drinks, kcal: 45, p: 2.4, c: 3.6, fat: 2.4, serving: 350, "12 oz"),
        f("Beer", .drinks, kcal: 43, p: 0.5, c: 3.6, fat: 0, serving: 355, "1 can"),
        f("Wine, red", .drinks, kcal: 85, p: 0.1, c: 2.6, fat: 0, serving: 147, "1 glass"),
        f("Sports Drink", .drinks, kcal: 26, p: 0, c: 6.5, fat: 0, serving: 591, "1 bottle"),
    ]

    public static let all: [FoodDefinition] =
        protein + dairy + grains + fruit + vegetables + legumes + nutsSeeds + fats + snacks + drinks

    public static let byName: [String: FoodDefinition] = {
        var map = [String: FoodDefinition]()
        for definition in all { map[definition.name] = definition }
        return map
    }()

    public static func definition(named name: String) -> FoodDefinition? { byName[name] }
    public static func foods(in category: FoodCategory) -> [FoodDefinition] { all.filter { $0.category == category } }
}

import 'package:flutter/material.dart';

class SubCategoryModel {
  final String id;
  final String ru;
  final String kz;
  final String ug;

  SubCategoryModel({
    required this.id,
    required this.ru,
    required this.kz,
    required this.ug,
  });
}

class CategoryModel {
  final String id;
  final String ru;
  final String kz;
  final String ug;
  final IconData icon;
  final Color color;
  final List<SubCategoryModel>? subCategories;

  CategoryModel({
    required this.id,
    required this.ru,
    required this.kz,
    required this.ug,
    required this.icon,
    required this.color,
    this.subCategories,
  });
}


class CategoryData {
  static final List<CategoryModel> categories = [
    CategoryModel(
      id: 'Авто', 
      ru: 'Авто', 
      kz: 'Автокөлік', 
      ug: 'Машина', 
      icon: Icons.directions_car_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'cars', ru: 'Легковые', kz: 'Жеңіл көліктер', ug: 'Кичик машина'),
        SubCategoryModel(id: 'trucks', ru: 'Грузовые', kz: 'Жүк көліктері', ug: 'Йүк машина'),
        SubCategoryModel(id: 'moto', ru: 'Мототехника', kz: 'Мототехника', ug: 'Мототехника'),
        SubCategoryModel(id: 'special', ru: 'Спецтехника', kz: 'Арнайы техника', ug: 'Мәхсус техника'),
        SubCategoryModel(id: 'parts', ru: 'Запчасти', kz: 'Қосалқы бөлшектер', ug: 'Запас части'),
        SubCategoryModel(id: 'tires', ru: 'Шины и диски', kz: 'Шиналар мен дискілер', ug: 'Чарх вә диск'),
      ],
    ),
    CategoryModel(
      id: 'Электроника', 
      ru: 'Электроника', 
      kz: 'Электроника', 
      ug: 'Электроника', 
      icon: Icons.smartphone_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'phones', ru: 'Телефоны', kz: 'Телефондар', ug: 'Телефон'),
        SubCategoryModel(id: 'computers', ru: 'Компьютеры', kz: 'Компьютерлер', ug: 'Компьютер'),
        SubCategoryModel(id: 'appliances', ru: 'Бытовая техника', kz: 'Тұрмыстық техника', ug: 'Өй җавазлири'),
      ],
    ),
    CategoryModel(
      id: 'Продукты', 
      ru: 'Еда', 
      kz: 'Өнімдер', 
      ug: 'Мәһсулатлар', 
      icon: Icons.shopping_basket_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'veggies', ru: 'Овощи/Зелень', kz: 'Көкөністер', ug: 'Көктат'),
        SubCategoryModel(id: 'fruits', ru: 'Фрукты', kz: 'Жемістер', ug: 'Мивә'),
        SubCategoryModel(id: 'dairy', ru: 'Молочные продукты', kz: 'Сүт өнімдері', ug: 'Сүт мәһсулатлири'),
        SubCategoryModel(id: 'meat', ru: 'Мясо', kz: 'Ет', ug: 'Гөш'),
        SubCategoryModel(id: 'bread', ru: 'Выпечка', kz: 'Нан өнімдері', ug: 'Нан'),
        SubCategoryModel(id: 'sweets', ru: 'Сладости', kz: 'Тәттілер', ug: 'Татлиқлар'),
        SubCategoryModel(id: 'honey', ru: 'Мед/Варенье', kz: 'Бал', ug: 'Һәсәл'),
      ],
    ),
    CategoryModel(
      id: 'Одежда', 
      ru: 'Одежда', 
      kz: 'Киім', 
      ug: 'Кийим', 
      icon: Icons.checkroom_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'men', ru: 'Мужская', kz: 'Ерлер', ug: 'Әрләр'),
        SubCategoryModel(id: 'women', ru: 'Женская', kz: 'Әйелдер', ug: 'Аяллар'),
        SubCategoryModel(id: 'kids', ru: 'Детская', kz: 'Балалар', ug: 'Балилар'),
      ],
    ),
    CategoryModel(
      id: 'Услуги', 
      ru: 'Услуги', 
      kz: 'Қызметтер', 
      ug: 'Хизмәтләр', 
      icon: Icons.build_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'repair', ru: 'Ремонт', kz: 'Жөндеу', ug: 'Ремит'),
        SubCategoryModel(id: 'transport', ru: 'Перевозки', kz: 'Тасымалдау', ug: 'Тошуш'),
        SubCategoryModel(id: 'beauty', ru: 'Красота', kz: 'Сұлулық', ug: 'Гөзәллик'),
        SubCategoryModel(id: 'education', ru: 'Обучение', kz: 'Оқыту', ug: 'Оқутуш'),
      ],
    ),
    CategoryModel(
      id: 'Работа', 
      ru: 'Работа', 
      kz: 'Жұмыс', 
      ug: 'Хизмәт', 
      icon: Icons.work_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'vacancies', ru: 'Вакансии', kz: 'Бос орындар', ug: 'Хизмәт'),
        SubCategoryModel(id: 'resumes', ru: 'Резюме', kz: 'Түйіндеме', ug: 'Резюме'),
      ],
    ),
    CategoryModel(
      id: 'Дом и Сад', 
      ru: 'Дом', 
      kz: 'Үй және бақша', 
      ug: 'Өй вә бағ', 
      icon: Icons.local_florist_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'furniture', ru: 'Мебель', kz: 'Жиһаз', ug: 'Җаваз'),
        SubCategoryModel(id: 'garden', ru: 'Сад и Огород', kz: 'Бақша', ug: 'Бағ'),
        SubCategoryModel(id: 'repair', ru: 'Ремонт', kz: 'Жөндеу', ug: 'Ремонт'),
      ],
    ),
    CategoryModel(
      id: 'Детский мир', 
      ru: 'Детям', 
      kz: 'Балалар әлемі', 
      ug: 'Балилар дуняси', 
      icon: Icons.child_care_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'toys', ru: 'Игрушки', kz: 'Ойыншықтар', ug: 'Оюнчуқ'),
        SubCategoryModel(id: 'strollers', ru: 'Коляски', kz: 'Арбалар', ug: 'Һарву'),
      ],
    ),
    CategoryModel(
      id: 'Недвижимость', 
      ru: 'Жилье', 
      kz: 'Жылжымайтын мүлік', 
      ug: 'Мүлүк', 
      icon: Icons.home_work_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'apartments', ru: 'Квартиры', kz: 'Пәтерлер', ug: 'Пәтер'),
        SubCategoryModel(id: 'houses', ru: 'Дома', kz: 'Үйлер', ug: 'Өйләр'),
        SubCategoryModel(id: 'land', ru: 'Участки', kz: 'Жер учаскелері', ug: 'Йәр'),
        SubCategoryModel(id: 'commercial', ru: 'Коммерческая', kz: 'Коммерциялық', ug: 'Тиҗарәт'),
      ],
    ),
    CategoryModel(
      id: 'Малбазар', 
      ru: 'Животные', 
      kz: 'Малбазар', 
      ug: 'Малбазар', 
      icon: Icons.pets_rounded, 
      color: const Color(0xFF4A80F0),
      subCategories: [
        SubCategoryModel(id: 'cattle', ru: 'КРС (Коровы/Быки)', kz: 'Ірі қара', ug: 'Кала'),
        SubCategoryModel(id: 'sheep', ru: 'Овцы/Козы', kz: 'Қой/Ешкі', ug: 'Қой/Өшкә'),
        SubCategoryModel(id: 'horses', ru: 'Лошади', kz: 'Жылқылар', ug: 'Ат'),
        SubCategoryModel(id: 'birds', ru: 'Птицы', kz: 'Құстар', ug: 'Қушлар'),
      ],
    ),
    CategoryModel(
      id: 'Отдам даром', 
      ru: 'Отдам даром', 
      kz: 'Тегін беремін', 
      ug: 'Һәқсиз беримән', 
      icon: Icons.volunteer_activism_rounded, 
      color: const Color(0xFF10B981), // Зеленый для даром
    ),
  ];
}

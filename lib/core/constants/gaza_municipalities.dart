class GazaMunicipality {
  final String nameAr;
  final String nameEn;
  final String governorate;
  const GazaMunicipality(this.nameAr, this.nameEn, this.governorate);
}

/// Virtual/default Gaza Strip municipality list used for account setup and
/// operational assignments. Values follow the published Gaza Strip local
/// authority/municipality listing used by CleanOps.
const gazaMunicipalities = <GazaMunicipality>[
  GazaMunicipality('بيت لاهيا', 'Beit Lahia', 'شمال غزة'),
  GazaMunicipality('أم النصر', 'Um Al-Naser', 'شمال غزة'),
  GazaMunicipality('بيت حانون', 'Beit Hanoun', 'شمال غزة'),
  GazaMunicipality('جباليا / النزلة', 'Jabalia / Al-Nazla', 'شمال غزة'),
  GazaMunicipality('مدينة غزة', 'Gaza City', 'غزة'),
  GazaMunicipality('الزهراء', 'Al-Zahra', 'غزة'),
  GazaMunicipality('المغراقة', 'Al-Mughraqa', 'غزة'),
  GazaMunicipality('وادي غزة', 'Wadi Gaza', 'غزة'),
  GazaMunicipality('النصيرات', 'Al-Nussairat', 'دير البلح'),
  GazaMunicipality('البريج', 'Al-Bureij', 'دير البلح'),
  GazaMunicipality('الزوايدة', 'Al-Zawaydah', 'دير البلح'),
  GazaMunicipality('المغازي', 'Al-Maghazi', 'دير البلح'),
  GazaMunicipality('المصدر', 'Al-Musaddar', 'دير البلح'),
  GazaMunicipality('دير البلح', 'Deir El-Balah', 'دير البلح'),
  GazaMunicipality('وادي السلقا', 'Wadi Al-Salqa', 'دير البلح'),
  GazaMunicipality('القرارة', 'Al-Qarara', 'خانيونس'),
  GazaMunicipality('خان يونس', 'Khan Younis', 'خانيونس'),
  GazaMunicipality('بني سهيلا', 'Bani Suhaila', 'خانيونس'),
  GazaMunicipality('عبسان الكبيرة', 'Abasan Al-Kabeera', 'خانيونس'),
  GazaMunicipality('عبسان الجديدة', 'Abasan Al-Jadeeda', 'خانيونس'),
  GazaMunicipality('خزاعة', 'Khuza’a', 'خانيونس'),
  GazaMunicipality('الفخاري', 'Al-Fukhari', 'خانيونس'),
  GazaMunicipality('رفح', 'Rafah', 'رفح'),
  GazaMunicipality('النصر', 'Al-Naser', 'رفح'),
  GazaMunicipality('الشوكة', 'Al-Shouka', 'رفح'),
];

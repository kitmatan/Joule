#!/usr/bin/env python3
"""
Generates complete Localizable.xcstrings for Joule with 8 languages:
en (English), de (German), fr (French), es (Spanish), zh-Hans (Simplified Chinese),
ja (Japanese), nb (Norwegian Bokmål), th (Thai).
"""

import json
import os

TRANSLATIONS = {
    " (Default)": {
        "comment": "Text appended to a vehicle name to indicate that it is the user's default vehicle.",
        "en": " (Default)",
        "de": " (Standard)",
        "fr": " (Par défaut)",
        "es": " (Predeterminado)",
        "zh-Hans": " (默认)",
        "ja": " (デフォルト)",
        "nb": " (Standard)",
        "th": " (ค่าเริ่มต้น)"
    },
    "(Default)": {
        "en": "(Default)",
        "de": "(Standard)",
        "fr": "(Par défaut)",
        "es": "(Predeterminado)",
        "zh-Hans": "(默认)",
        "ja": "(デフォルト)",
        "nb": "(Standard)",
        "th": "(ค่าเริ่มต้น)"
    },
    "**Annual Rate** requires at least 4 sessions spanning 60 days to calculate a yearly trend.": {
        "comment": "A description of the annual rate of battery degradation.",
        "en": "**Annual Rate** requires at least 4 sessions spanning 60 days to calculate a yearly trend.",
        "de": "**Jährliche Rate** erfordert mindestens 4 Ladevorgänge über 60 Tage, um einen Jahrestrend zu berechnen.",
        "fr": "Le **Taux annuel** nécessite au moins 4 sessions réparties sur 60 jours pour calculer une tendance annuelle.",
        "es": "La **Tasa anual** requiere al menos 4 sesiones durante 60 días para calcular una tendencia anual.",
        "zh-Hans": "**年化衰减率**需要至少跨越 60 天的 4 次充电记录以计算年度趋势。",
        "ja": "**年間劣化率**の計算には、60日間にわたる少なくとも4回の充電セッションが必要です。",
        "nb": "**Årlig rate** krever minst 4 ladeøkter over 60 dager for å beregne en årlig trend.",
        "th": "**อัตราเสื่อมรายปี** ต้องใช้ข้อมูลการชาร์จอย่างน้อย 4 ครั้งในช่วงเวลา 60 วันขึ้นไป เพื่อคำนวณแนวโน้มรายปี"
    },
    "**Annual Rate** requires at least 60 days of charging history to compute a yearly degradation trend.": {
        "comment": "A description of the annual rate of battery degradation.",
        "en": "**Annual Rate** requires at least 60 days of charging history to compute a yearly degradation trend.",
        "de": "**Jährliche Rate** erfordert mindestens 60 Tage Ladehistorie, um einen jährlichen Degradationstrend zu berechnen.",
        "fr": "Le **Taux annuel** nécessite au moins 60 jours d'historique de recharge pour calculer une tendance de dégradation annuelle.",
        "es": "La **Tasa anual** requiere al menos 60 días de historial de carga para calcular una tendencia de degradación anual.",
        "zh-Hans": "**年化衰减率**需要至少 60 天的充电历史记录以计算年度衰减趋势。",
        "ja": "**年間劣化率**の計算には、少なくとも60日間の充電履歴が必要です。",
        "nb": "**Årlig rate** krever minst 60 dagers ladehistorikk for å beregne en årlig degraderingstrend.",
        "th": "**อัตราเสื่อมรายปี** ต้องใช้ประวัติการชาร์จอย่างน้อย 60 วัน เพื่อคำนวณแนวโน้มการเสื่อมสภาพรายปี"
    },
    "**Degradation Rate** requires at least 4 sessions with odometer readings spanning %@ of driving to establish a reliable distance-based trend.": {
        "en": "**Degradation Rate** requires at least 4 sessions with odometer readings spanning %1$@ of driving to establish a reliable distance-based trend.",
        "de": "**Degradationsrate** erfordert mindestens 4 Ladevorgänge mit Kilometerstand über %1$@ Fahrstrecke, um einen verlässlichen distanzbasierten Trend zu ermitteln.",
        "fr": "Le **Taux de dégradation** nécessite au moins 4 sessions avec kilométrage sur %1$@ de conduite pour établir une tendance kilométrique fiable.",
        "es": "La **Tasa de degradación** requiere al menos 4 sesiones con odómetro durante %1$@ de conducción para establecer una tendencia por distancia confiable.",
        "zh-Hans": "**里程衰减率**需要至少 4 次包含里程读数且跨越 %1$@ 行驶里程的充电记录，以建立可靠的距离趋势。",
        "ja": "**劣化率**の距離ベースの傾向を算出するには、走行距離 %1$@ にわたるオドメーター付きの充電セッションが4回以上必要です。",
        "nb": "**Degraderingsrate** krever minst 4 ladeøkter med kilometerteller over %1$@ kjøring for å etablere en pålitelig avstandsbasert trend.",
        "th": "**อัตราการเสื่อมสภาพ** ต้องใช้ข้อมูลที่มีเลขไมล์อย่างน้อย 4 ครั้งในช่วงระยะทางการขับขี่ %1$@ เพื่อประเมินแนวโน้มตามระยะทางที่แม่นยำ"
    },
    "**Degradation Rate** requires at least 4 sessions with odometer readings spanning %@ of driving.": {
        "en": "**Degradation Rate** requires at least 4 sessions with odometer readings spanning %1$@ of driving.",
        "de": "**Degradationsrate** erfordert mindestens 4 Ladevorgänge mit Kilometerstand über %1$@ Fahrstrecke.",
        "fr": "Le **Taux de dégradation** nécessite au moins 4 sessions avec kilométrage sur %1$@ de conduite.",
        "es": "La **Tasa de degradación** requiere al menos 4 sesiones con odómetro durante %1$@ de conducción.",
        "zh-Hans": "**里程衰减率**需要至少 4 次包含里程读数且跨越 %1$@ 行驶里程的充电记录。",
        "ja": "**劣化率**の算出には、%1$@ の走行にわたるオドメーター付きセッションが4回以上必要です。",
        "nb": "**Degraderingsrate** krever minst 4 ladeøkter med kilometerteller over %1$@ kjøring.",
        "th": "**อัตราการเสื่อมสภาพ** ต้องใช้ข้อมูลที่มีเลขไมล์อย่างน้อย 4 ครั้งในช่วงระยะทางการขับขี่ %1$@"
    },
    "/ 100": {
        "comment": "A unit of measurement for a percentage.",
        "en": "/ 100",
        "de": "/ 100",
        "fr": "/ 100",
        "es": "/ 100",
        "zh-Hans": "/ 100",
        "ja": "/ 100",
        "nb": "/ 100",
        "th": "/ 100"
    },
    "%@": {
        "en": "%1$@",
        "de": "%1$@",
        "fr": "%1$@",
        "es": "%1$@",
        "zh-Hans": "%1$@",
        "ja": "%1$@",
        "nb": "%1$@",
        "th": "%1$@"
    },
    "%@ (%@) Battery Care": {
        "en": "%1$@ (%2$@) Battery Care",
        "de": "%1$@ (%2$@) Batteriepflege",
        "fr": "Entretien de la batterie %1$@ (%2$@)",
        "es": "Cuidado de batería %1$@ (%2$@)",
        "zh-Hans": "%1$@ (%2$@) 电池维护建议",
        "ja": "%1$@ (%2$@) バッテリーケア",
        "nb": "%1$@ (%2$@) Batteripleie",
        "th": "การดูแลแบตเตอรี่ %1$@ (%2$@)"
    },
    "%@ %@": {
        "en": "%1$@ %2$@",
        "de": "%1$@ %2$@",
        "fr": "%1$@ %2$@",
        "es": "%1$@ %2$@",
        "zh-Hans": "%1$@ %2$@",
        "ja": "%1$@ %2$@",
        "nb": "%1$@ %2$@",
        "th": "%1$@ %2$@"
    },
    "%@ %@ (%@ kWh)": {
        "en": "%1$@ %2$@ (%3$@ kWh)",
        "de": "%1$@ %2$@ (%3$@ kWh)",
        "fr": "%1$@ %2$@ (%3$@ kWh)",
        "es": "%1$@ %2$@ (%3$@ kWh)",
        "zh-Hans": "%1$@ %2$@ (%3$@ kWh)",
        "ja": "%1$@ %2$@ (%3$@ kWh)",
        "nb": "%1$@ %2$@ (%3$@ kWh)",
        "th": "%1$@ %2$@ (%3$@ kWh)"
    },
    "%@ cyc": {
        "en": "%1$@ cyc",
        "de": "%1$@ Zyklen",
        "fr": "%1$@ cyc",
        "es": "%1$@ cic",
        "zh-Hans": "%1$@ 次循环",
        "ja": "%1$@ サイクル",
        "nb": "%1$@ sykl",
        "th": "%1$@ รอบชาร์จ"
    },
    "%@ Duplicate %@ Found": {
        "en": "%1$@ Duplicate %2$@ Found",
        "de": "%1$@ doppelte %2$@ gefunden",
        "fr": "%1$@ %2$@ en double trouvé(s)",
        "es": "%1$@ %2$@ duplicado(s) encontrado(s)",
        "zh-Hans": "发现 %1$@ 条重复 %2$@",
        "ja": "%1$@ 件の重複する%2$@が見つかりました",
        "nb": "%1$@ dupliserte %2$@ funnet",
        "th": "พบ %2$@ ซ้ำ %1$@ รายการ"
    },
    "%@ Equivalent gas running cost: %@.": {
        "en": "%1$@ Equivalent gas running cost: %2$@.",
        "de": "%1$@ Entsprechende Benzinkosten: %2$@.",
        "fr": "%1$@ Coût équivalent en essence : %2$@.",
        "es": "%1$@ Costo equivalente en gasolina: %2$@.",
        "zh-Hans": "%1$@ 等效燃油行驶成本：%2$@。",
        "ja": "%1$@ ガソリン換算走行コスト: %2$@。",
        "nb": "%1$@ Tilsvarende bensinkostnad: %2$@.",
        "th": "%1$@ ค่าใช้จ่ายเทียบเท่าน้ำมัน: %2$@"
    },
    "%@ found": {
        "en": "%1$@ found",
        "de": "%1$@ gefunden",
        "fr": "%1$@ trouvé(s)",
        "es": "%1$@ encontrado(s)",
        "zh-Hans": "找到 %1$@ 项",
        "ja": "%1$@ 件見つかりました",
        "nb": "%1$@ funnet",
        "th": "พบ %1$@ รายการ"
    },
    "%@ sessions • %@": {
        "en": "%1$@ sessions • %2$@",
        "de": "%1$@ Ladevorgänge • %2$@",
        "fr": "%1$@ sessions • %2$@",
        "es": "%1$@ sesiones • %2$@",
        "zh-Hans": "%1$@ 次充电 • %2$@",
        "ja": "%1$@ 回の充電 • %2$@",
        "nb": "%1$@ økter • %2$@",
        "th": "%1$@ ครั้ง • %2$@"
    },
    "%@ sessions analyzed": {
        "en": "%1$@ sessions analyzed",
        "de": "%1$@ Ladevorgänge analysiert",
        "fr": "%1$@ sessions analysées",
        "es": "%1$@ sesiones analizadas",
        "zh-Hans": "已分析 %1$@ 次充电记录",
        "ja": "%1$@ 件のセッションを分析済み",
        "nb": "%1$@ ladeøkter analysert",
        "th": "วิเคราะห์แล้ว %1$@ ครั้ง"
    },
    "%@ tips": {
        "en": "%1$@ tips",
        "de": "%1$@ Tipps",
        "fr": "%1$@ conseils",
        "es": "%1$@ consejos",
        "zh-Hans": "%1$@ 条建议",
        "ja": "%1$@ 件のヒント",
        "nb": "%1$@ tips",
        "th": "%1$@ คำแนะนำ"
    },
    "%@ vehicles combined": {
        "en": "%1$@ vehicles combined",
        "de": "%1$@ Fahrzeuge kombiniert",
        "fr": "%1$@ véhicules combinés",
        "es": "%1$@ vehículos combinados",
        "zh-Hans": "共 %1$@ 辆车汇总",
        "ja": "%1$@ 台の合計",
        "nb": "%1$@ kjøretøy totalt",
        "th": "รวม %1$@ คัน"
    },
    "%@: %@. Used as baseline for State of Health (SoH) and degradation analytics.": {
        "en": "%1$@: %2$@. Used as baseline for State of Health (SoH) and degradation analytics.",
        "de": "%1$@: %2$@. Dient als Basis für State of Health (SoH) und Degradationsanalysen.",
        "fr": "%1$@ : %2$@. Utilisé comme référence pour l'état de santé (SoH) et l'analyse de dégradation.",
        "es": "%1$@: %2$@. Utilizado como base para el estado de salud (SoH) y análisis de degradación.",
        "zh-Hans": "%1$@: %2$@。用作电池健康状态 (SoH) 和衰减分析的基准。",
        "ja": "%1$@: %2$@。バッテリー健全度 (SoH) および劣化分析の基準として使用されます。",
        "nb": "%1$@: %2$@. Brukes som referanse for batterihelse (SoH) og degraderingsanalyse.",
        "th": "%1$@: %2$@ ใช้เป็นเกณฑ์มาตรฐานสำหรับสุขภาพแบตเตอรี่ (SoH) และการวิเคราะห์การเสื่อมสภาพ"
    },
    "%@/%@": {
        "en": "%1$@/%2$@",
        "de": "%1$@/%2$@",
        "fr": "%1$@/%2$@",
        "es": "%1$@/%2$@",
        "zh-Hans": "%1$@/%2$@",
        "ja": "%1$@/%2$@",
        "nb": "%1$@/%2$@",
        "th": "%1$@/%2$@"
    },
    "%@%%": {
        "en": "%1$@%%",
        "de": "%1$@ %%",
        "fr": "%1$@ %%",
        "es": "%1$@%%",
        "zh-Hans": "%1$@%%",
        "ja": "%1$@%%",
        "nb": "%1$@ %%",
        "th": "%1$@%%"
    },
    "%@/kWh": {
        "en": "%1$@/kWh",
        "de": "%1$@/kWh",
        "fr": "%1$@/kWh",
        "es": "%1$@/kWh",
        "zh-Hans": "%1$@/kWh",
        "ja": "%1$@/kWh",
        "nb": "%1$@/kWh",
        "th": "%1$@/kWh"
    },
    "%@)": {
        "en": "%1$@)",
        "de": "%1$@)",
        "fr": "%1$@)",
        "es": "%1$@)",
        "zh-Hans": "%1$@)",
        "ja": "%1$@)",
        "nb": "%1$@)",
        "th": "%1$@)"
    },
    "•": {
        "comment": "A unit of energy.",
        "en": "•",
        "de": "•",
        "fr": "•",
        "es": "•",
        "zh-Hans": "•",
        "ja": "•",
        "nb": "•",
        "th": "•"
    },
    "1 Year": {
        "en": "1 Year",
        "de": "1 Jahr",
        "fr": "1 an",
        "es": "1 año",
        "zh-Hans": "1 年",
        "ja": "1年",
        "nb": "1 år",
        "th": "1 ปี"
    },
    "100% Factory": {
        "en": "100% Factory",
        "de": "100% Werkswert",
        "fr": "100 % Usine",
        "es": "100% Fábrica",
        "zh-Hans": "100% 出厂标称",
        "ja": "100% 工場定格",
        "nb": "100 % fabrikk",
        "th": "100% มาตรฐานโรงงาน"
    },
    "6 Months": {
        "en": "6 Months",
        "de": "6 Monate",
        "fr": "6 mois",
        "es": "6 meses",
        "zh-Hans": "6 个月",
        "ja": "6か月",
        "nb": "6 måneder",
        "th": "6 เดือน"
    },
    "AC": {
        "en": "AC",
        "de": "AC",
        "fr": "AC",
        "es": "CA",
        "zh-Hans": "交流 (AC)",
        "ja": "普通充電 (AC)",
        "nb": "AC",
        "th": "AC"
    },
    "AC / DC Ratio": {
        "en": "AC / DC Ratio",
        "de": "AC / DC Verhältnis",
        "fr": "Ratio AC / DC",
        "es": "Relación CA / CC",
        "zh-Hans": "交流 / 直流比例",
        "ja": "普通 / 急速 比率",
        "nb": "AC / DC-forhold",
        "th": "สัดส่วน AC / DC"
    },
    "AC Charging Efficiency": {
        "en": "AC Charging Efficiency",
        "de": "AC-Ladeeffizienz",
        "fr": "Efficacité de charge AC",
        "es": "Eficiencia de carga CA",
        "zh-Hans": "交流充电效率",
        "ja": "普通充電 (AC) 効率",
        "nb": "AC-ladeeffektivitet",
        "th": "ประสิทธิภาพการชาร์จ AC"
    },
    "AC Efficiency": {
        "en": "AC Efficiency",
        "de": "AC-Wirkungsgrad",
        "fr": "Efficacité AC",
        "es": "Eficiencia CA",
        "zh-Hans": "交流充电效率",
        "ja": "普通充電 (AC) 効率",
        "nb": "AC-effektivitet",
        "th": "ประสิทธิภาพ AC"
    },
    "AC Efficiency (OBC)": {
        "en": "AC Efficiency (OBC)",
        "de": "AC-Wirkungsgrad (OBC)",
        "fr": "Efficacité AC (OBC)",
        "es": "Eficiencia CA (OBC)",
        "zh-Hans": "交流车载充电机效率 (OBC)",
        "ja": "車載充電器効率 (OBC)",
        "nb": "AC-effektivitet (OBC)",
        "th": "ประสิทธิภาพ AC (OBC)"
    },
    "Account ID": {
        "en": "Account ID",
        "de": "Konto-ID",
        "fr": "Identifiant du compte",
        "es": "ID de cuenta",
        "zh-Hans": "账号 ID",
        "ja": "アカウント ID",
        "nb": "Konto-ID",
        "th": "รหัสบัญชี"
    },
    "Actionable Recommendations": {
        "en": "Actionable Recommendations",
        "de": "Handlungsempfehlungen",
        "fr": "Recommandations pratiques",
        "es": "Recomendaciones prácticas",
        "zh-Hans": "实用优化建议",
        "ja": "実用的な推奨事項",
        "nb": "Praktiske anbefalinger",
        "th": "คำแนะนำที่นำไปใช้ได้จริง"
    },
    "Active": {
        "en": "Active",
        "de": "Aktiv",
        "fr": "Actif",
        "es": "Activo",
        "zh-Hans": "当前使用",
        "ja": "使用中",
        "nb": "Aktiv",
        "th": "กำลังใช้งาน"
    },
    "Active Rate": {
        "en": "Active Rate",
        "de": "Aktiver Tarif",
        "fr": "Tarif actif",
        "es": "Tarifa activa",
        "zh-Hans": "当前费率",
        "ja": "適用レート",
        "nb": "Aktiv sats",
        "th": "อัตราค่าไฟที่ใช้อยู่"
    },
    "Add Charging Session": {
        "en": "Add Charging Session",
        "de": "Ladevorgang hinzufügen",
        "fr": "Ajouter une session de recharge",
        "es": "Agregar sesión de carga",
        "zh-Hans": "添加充电记录",
        "ja": "充電セッションを追加",
        "nb": "Legg til ladeøkt",
        "th": "เพิ่มบันทึกการชาร์จ"
    },
    "Add New Vehicle…": {
        "en": "Add New Vehicle…",
        "de": "Neues Fahrzeug hinzufügen…",
        "fr": "Ajouter un nouveau véhicule…",
        "es": "Agregar nuevo vehículo…",
        "zh-Hans": "添加新车辆…",
        "ja": "新しい車両を追加…",
        "nb": "Legg til nytt kjøretøy…",
        "th": "เพิ่มรถยนต์ใหม่…"
    },
    "Add Session": {
        "en": "Add Session",
        "de": "Ladevorgang erfassen",
        "fr": "Ajouter une session",
        "es": "Añadir sesión",
        "zh-Hans": "添加记录",
        "ja": "セッション追加",
        "nb": "Legg til økt",
        "th": "เพิ่มรายการ"
    },
    "Add Vehicle": {
        "en": "Add Vehicle",
        "de": "Fahrzeug hinzufügen",
        "fr": "Ajouter un véhicule",
        "es": "Agregar vehículo",
        "zh-Hans": "添加车辆",
        "ja": "車両を追加",
        "nb": "Legg til kjøretøy",
        "th": "เพิ่มรถยนต์"
    },
    "Add Vehicle…": {
        "en": "Add Vehicle…",
        "de": "Fahrzeug hinzufügen…",
        "fr": "Ajouter un véhicule…",
        "es": "Agregar vehículo…",
        "zh-Hans": "添加车辆…",
        "ja": "車両を追加…",
        "nb": "Legg til kjøretøy…",
        "th": "เพิ่มรถยนต์…"
    },
    "All Garage Vehicles": {
        "en": "All Garage Vehicles",
        "de": "Alle Fahrzeuge der Garage",
        "fr": "Tous les véhicules du garage",
        "es": "Todos los vehículos del garaje",
        "zh-Hans": "车库所有车辆",
        "ja": "ガレージの全車両",
        "nb": "Alle biler i garasjen",
        "th": "รถทุกคันในโรงรถ"
    },
    "All Time": {
        "en": "All Time",
        "de": "Gesamtzeitraum",
        "fr": "Tout l'historique",
        "es": "Todo el tiempo",
        "zh-Hans": "全部时间",
        "ja": "全期間",
        "nb": "All tid",
        "th": "ทั้งหมด"
    },
    "All Vehicles": {
        "en": "All Vehicles",
        "de": "Alle Fahrzeuge",
        "fr": "Tous les véhicules",
        "es": "Todos los vehículos",
        "zh-Hans": "所有车辆",
        "ja": "すべての車両",
        "nb": "Alle kjøretøy",
        "th": "รถทุกคัน"
    },
    "All charging sessions and battery analytics are stored locally on this device. Sign in with Google to enable automatic cloud backup and cross-device sync.": {
        "en": "All charging sessions and battery analytics are stored locally on this device. Sign in with Google to enable automatic cloud backup and cross-device sync.",
        "de": "Alle Ladevorgänge und Batterieanalysen werden lokal auf diesem Gerät gespeichert. Melden Sie sich mit Google an, um automatische Cloud-Backups und geräteübergreifende Synchronisierung zu aktivieren.",
        "fr": "Toutes les sessions de recharge et analyses de batterie sont stockées localement sur cet appareil. Connectez-vous avec Google pour activer la sauvegarde automatique et la synchronisation multi-appareils.",
        "es": "Todas las sesiones de carga y análisis de batería se guardan localmente en este dispositivo. Inicia sesión con Google para habilitar copias de seguridad automáticas y sincronización entre dispositivos.",
        "zh-Hans": "所有充电记录与电池分析数据均存储在此设备的本地。使用 Google 登录可启用自动云备份与跨设备多端同步。",
        "ja": "すべての充電セッションおよびバッテリー分析は、このデバイスのローカルに保存されます。Google でサインインすると、自動クラウドバックアップとデバイス間同期が有効になります。",
        "nb": "Alle ladeøkter og batterianalyser lagres lokalt på denne enheten. Logg inn med Google for å aktivere automatisk sikkerhetskopi i skyen og synkronisering mellom enheter.",
        "th": "บันทึกการชาร์จและการวิเคราะห์แบตเตอรี่ทั้งหมดจะถูกจัดเก็บไว้ในเครื่องนี้ เข้าสู่ระบบด้วย Google เพื่อเปิดใช้งานการสำรองข้อมูลบนคลาวด์และการซิงค์ระหว่างอุปกรณ์โดยอัตโนมัติ"
    },
    "Annual Degradation Rate": {
        "en": "Annual Degradation Rate",
        "de": "Jährliche Degradationsrate",
        "fr": "Taux de dégradation annuel",
        "es": "Tasa de degradación anual",
        "zh-Hans": "年化衰减率",
        "ja": "年間劣化率",
        "nb": "Årlig degraderingsrate",
        "th": "อัตราการเสื่อมสภาพรายปี"
    },
    "Annual Rate": {
        "en": "Annual Rate",
        "de": "Jährliche Rate",
        "fr": "Taux annuel",
        "es": "Tasa anual",
        "zh-Hans": "年化衰减率",
        "ja": "年間劣化率",
        "nb": "Årlig rate",
        "th": "อัตราเสื่อมรายปี"
    },
    "Appearance": {
        "en": "Appearance",
        "de": "Erscheinungsbild",
        "fr": "Apparence",
        "es": "Apariencia",
        "zh-Hans": "外观",
        "ja": "外観",
        "nb": "Utseende",
        "th": "การแสดงผล"
    },
    "Apply": {
        "en": "Apply",
        "de": "Anwenden",
        "fr": "Appliquer",
        "es": "Aplicar",
        "zh-Hans": "应用",
        "ja": "適用",
        "nb": "Bruk",
        "th": "นำไปใช้"
    },
    "Apply Extracted Values to Session": {
        "en": "Apply Extracted Values to Session",
        "de": "Extrahierte Werte für Ladevorgang übernehmen",
        "fr": "Appliquer les valeurs extraites à la session",
        "es": "Aplicar valores extraídos a la sesión",
        "zh-Hans": "将识别的数据填入充电记录",
        "ja": "抽出した値をセッションに適用",
        "nb": "Bruk uthentede verdier på økten",
        "th": "นำค่าที่สแกนได้ไปใช้ในการบันทึก"
    },
    "Are you sure you want to delete %@? Any charging sessions previously linked to this car will remain in your history and reassign to your primary vehicle.": {
        "en": "Are you sure you want to delete %1$@? Any charging sessions previously linked to this car will remain in your history and reassign to your primary vehicle.",
        "de": "Möchten Sie %1$@ wirklich löschen? Zugehörige Ladevorgänge bleiben im Verlauf und werden Ihrem Hauptfahrzeug zugewiesen.",
        "fr": "Voulez-vous vraiment supprimer %1$@ ? Les sessions associées resteront dans l'historique et seront réattribuées à votre véhicule principal.",
        "es": "¿Seguro que deseas eliminar %1$@? Las sesiones vinculadas se conservarán en tu historial y se reasignarán a tu vehículo principal.",
        "zh-Hans": "确定要删除 %1$@ 吗？之前关联至该车辆的充电记录将保留在历史中，并重新归属至您的主车辆。",
        "ja": "%1$@ を削除してもよろしいですか？関連付けられていた充電セッションは履歴に残り、メイン車両に再割り当てされます。",
        "nb": "Er du sikker på at du vil slette %1$@? Ladeøkter knyttet til denne bilen forblir i historikken og tilordnes hovedkjøretøyet ditt.",
        "th": "คุณแน่ใจหรือไม่ว่าต้องการลบ %1$@? ข้อมูลการชาร์จของรถคันนี้จะยังคงอยู่ในประวัติและถูกย้ายไปยังรถหลักของคุณ"
    },
    "Are you sure you want to delete this session?": {
        "en": "Are you sure you want to delete this session?",
        "de": "Möchten Sie diesen Ladevorgang wirklich löschen?",
        "fr": "Voulez-vous vraiment supprimer cette session ?",
        "es": "¿Seguro que deseas eliminar esta sesión?",
        "zh-Hans": "确定要删除此充电记录吗？",
        "ja": "このセッションを削除してもよろしいですか？",
        "nb": "Er du sikker på at du vil slette denne ladeøkten?",
        "th": "คุณแน่ใจหรือไม่ว่าต้องการลบรายการชาร์จนี้?"
    },
    "Are you sure you want to delete the charging session at %@ on %@?": {
        "en": "Are you sure you want to delete the charging session at %1$@ on %2$@?",
        "de": "Möchten Sie den Ladevorgang bei %1$@ am %2$@ wirklich löschen?",
        "fr": "Voulez-vous vraiment supprimer la session de recharge à %1$@ le %2$@ ?",
        "es": "¿Seguro que deseas eliminar la sesión de carga en %1$@ el %2$@?",
        "zh-Hans": "确定要删除 %2$@ 在 %1$@ 的充电记录吗？",
        "ja": "%2$@ に %1$@ で行った充電セッションを削除してもよろしいですか？",
        "nb": "Er du sikker på at du vil slette ladeøkten på %1$@ den %2$@?",
        "th": "คุณแน่ใจหรือไม่ว่าต้องการลบรายการชาร์จที่ %1$@ เมื่อวันที่ %2$@?"
    },
    "Auto": {
        "en": "Auto",
        "de": "Automatisch",
        "fr": "Automatique",
        "es": "Automático",
        "zh-Hans": "自动",
        "ja": "自動",
        "nb": "Auto",
        "th": "อัตโนมัติ"
    },
    "Average AC Power": {
        "en": "Average AC Power",
        "de": "Durchschnittliche AC-Leistung",
        "fr": "Puissance AC moyenne",
        "es": "Potencia CA promedio",
        "zh-Hans": "平均交流功率",
        "ja": "平均普通充電 (AC) 出力",
        "nb": "Gjennomsnittlig AC-effekt",
        "th": "กำลังไฟ AC เฉลี่ย"
    },
    "Average Cost / Session": {
        "en": "Average Cost / Session",
        "de": "Durchschnittskosten / Ladevorgang",
        "fr": "Coût moyen / session",
        "es": "Costo promedio / sesión",
        "zh-Hans": "单次平均花费",
        "ja": "セッションあたり平均費用",
        "nb": "Gjennomsnittskostnad / økt",
        "th": "ค่าใช้จ่ายเฉลี่ย / ครั้ง"
    },
    "Average DC Power": {
        "en": "Average DC Power",
        "de": "Durchschnittliche DC-Leistung",
        "fr": "Puissance DC moyenne",
        "es": "Potencia CC promedio",
        "zh-Hans": "平均直流功率",
        "ja": "平均急速充電 (DC) 出力",
        "nb": "Gjennomsnittlig DC-effekt",
        "th": "กำลังไฟ DC เฉลี่ย"
    },
    "Average Energy / Session": {
        "en": "Average Energy / Session",
        "de": "Durchschnittsenergie / Ladevorgang",
        "fr": "Énergie moyenne / session",
        "es": "Energía promedio / sesión",
        "zh-Hans": "单次平均充电量",
        "ja": "セッションあたり平均電力量",
        "nb": "Gjennomsnittlig energi / økt",
        "th": "พลังงานเฉลี่ย / ครั้ง"
    },
    "Average Speed": {
        "en": "Average Speed",
        "de": "Durchschnittsleistung",
        "fr": "Vitesse moyenne",
        "es": "Velocidad promedio",
        "zh-Hans": "平均充电功率",
        "ja": "平均充電速度",
        "nb": "Gjennomsnittshastighet",
        "th": "ความเร็วเฉลี่ย"
    },
    "Averages & Efficiency": {
        "en": "Averages & Efficiency",
        "de": "Durchschnitt & Effizienz",
        "fr": "Moyennes et efficacité",
        "es": "Promedios y eficiencia",
        "zh-Hans": "平均值与能效",
        "ja": "平均値と電費効率",
        "nb": "Gjennomsnitt og effektivitet",
        "th": "ค่าเฉลี่ยและประสิทธิภาพ"
    },
    "Avg Cost / Session": {
        "en": "Avg Cost / Session",
        "de": "Ø Kosten / Ladevorgang",
        "fr": "Coût moy. / session",
        "es": "Costo prom. / sesión",
        "zh-Hans": "单次均费",
        "ja": "平均費用 / 回",
        "nb": "Snittkostnad / økt",
        "th": "ค่าเฉลี่ยต่อครั้ง"
    },
    "Avg Energy / Session": {
        "en": "Avg Energy / Session",
        "de": "Ø Energie / Ladevorgang",
        "fr": "Énergie moy. / session",
        "es": "Energía prom. / sesión",
        "zh-Hans": "单次均电量",
        "ja": "平均電力量 / 回",
        "nb": "Snittenergi / økt",
        "th": "พลังงานเฉลี่ย / ครั้ง"
    },
    "Avg Monthly Cost": {
        "en": "Avg Monthly Cost",
        "de": "Ø Monatliche Kosten",
        "fr": "Coût mensuel moy.",
        "es": "Costo mensual prom.",
        "zh-Hans": "月均花费",
        "ja": "月平均コスト",
        "nb": "Snitt månedskostnad",
        "th": "ค่าใช้จ่ายเฉลี่ยต่อเดือน"
    },
    "Avg Monthly Energy": {
        "en": "Avg Monthly Energy",
        "de": "Ø Monatliche Energie",
        "fr": "Énergie mensuelle moy.",
        "es": "Energía mensual prom.",
        "zh-Hans": "月均充电量",
        "ja": "月平均電力量",
        "nb": "Snitt månedsenergi",
        "th": "พลังงานเฉลี่ยต่อเดือน"
    },
    "Avg Power": {
        "en": "Avg Power",
        "de": "Ø Leistung",
        "fr": "Puissance moy.",
        "es": "Potencia prom.",
        "zh-Hans": "平均功率",
        "ja": "平均出力",
        "nb": "Snitteffekt",
        "th": "กำลังไฟเฉลี่ย"
    },
    "Avg Rate": {
        "en": "Avg Rate",
        "de": "Ø Tarif",
        "fr": "Tarif moy.",
        "es": "Tarifa prom.",
        "zh-Hans": "平均电价",
        "ja": "平均レート",
        "nb": "Snittpris",
        "th": "ค่าไฟเฉลี่ย"
    },
    "Avg Speed": {
        "en": "Avg Speed",
        "de": "Ø Leistung",
        "fr": "Vitesse moy.",
        "es": "Velocidad prom.",
        "zh-Hans": "平均功率",
        "ja": "平均速度",
        "nb": "Snitthastighet",
        "th": "ความเร็วเฉลี่ย"
    },
    "Baseline": {
        "en": "Baseline",
        "de": "Basiswert",
        "fr": "Référence",
        "es": "Línea base",
        "zh-Hans": "对比基准",
        "ja": "基準値",
        "nb": "Referanse",
        "th": "เกณฑ์เปรียบเทียบ"
    },
    "Baseline Fuel Price": {
        "en": "Baseline Fuel Price",
        "de": "Basis-Kraftstoffpreis",
        "fr": "Prix de base du carburant",
        "es": "Precio base del combustible",
        "zh-Hans": "基准燃油价格",
        "ja": "基準ガソリン価格",
        "nb": "Referansebensinpris",
        "th": "ราคาน้ำมันอ้างอิง"
    },
    "Baseline: %@ @ %@": {
        "en": "Baseline: %1$@ @ %2$@",
        "de": "Basis: %1$@ @ %2$@",
        "fr": "Référence : %1$@ @ %2$@",
        "es": "Base: %1$@ @ %2$@",
        "zh-Hans": "基准：%1$@ @ %2$@",
        "ja": "基準: %1$@ @ %2$@",
        "nb": "Referanse: %1$@ @ %2$@",
        "th": "เกณฑ์อ้างอิง: %1$@ @ %2$@"
    },
    "Basic Info": {
        "en": "Basic Info",
        "de": "Grundinformationen",
        "fr": "Informations de base",
        "es": "Información básica",
        "zh-Hans": "基本信息",
        "ja": "基本情報",
        "nb": "Grunnleggende info",
        "th": "ข้อมูลพื้นฐาน"
    },
    "Battery & Range Specifications": {
        "en": "Battery & Range Specifications",
        "de": "Batterie- & Reichweiten-Spezifikationen",
        "fr": "Spécifications de batterie et autonomie",
        "es": "Especificaciones de batería y autonomía",
        "zh-Hans": "电池容量与续航参数",
        "ja": "バッテリーおよび航続距離スペック",
        "nb": "Batteri- og rekkeviddespesifikasjoner",
        "th": "ข้อมูลจำเพาะแบตเตอรี่และระยะทาง"
    },
    "Battery Capacity": {
        "en": "Battery Capacity",
        "de": "Batteriekapazität",
        "fr": "Capacité de la batterie",
        "es": "Capacidad de la batería",
        "zh-Hans": "电池容量",
        "ja": "バッテリー容量",
        "nb": "Batterikapasitet",
        "th": "ความจุแบตเตอรี่"
    },
    "Battery Care Grade: %@": {
        "en": "Battery Care Grade: %1$@",
        "de": "Batteriepflege-Note: %1$@",
        "fr": "Note d'entretien de la batterie : %1$@",
        "es": "Nota de cuidado de batería: %1$@",
        "zh-Hans": "电池养护评级：%1$@",
        "ja": "バッテリーケア評価: %1$@",
        "nb": "Batteripleie-karakter: %1$@",
        "th": "เกรดการดูแลแบตเตอรี่: %1$@"
    },
    "Battery Certificate": {
        "en": "Battery Certificate",
        "de": "Batteriezertifikat",
        "fr": "Certificat de batterie",
        "es": "Certificado de batería",
        "zh-Hans": "电池健康证书",
        "ja": "バッテリー証明書",
        "nb": "Batterisertifikat",
        "th": "ใบรับรองสุขภาพแบตเตอรี่"
    },
    "Battery Chemistry": {
        "en": "Battery Chemistry",
        "de": "Batteriechemie",
        "fr": "Chimie de la batterie",
        "es": "Química de la batería",
        "zh-Hans": "电池化学类型",
        "ja": "バッテリー種類",
        "nb": "Batterikjemi",
        "th": "ชนิดของเคมีแบตเตอรี่"
    },
    "Battery Degradation Trend": {
        "en": "Battery Degradation Trend",
        "de": "Batterie-Degradationstrend",
        "fr": "Tendance de dégradation de la batterie",
        "es": "Tendencia de degradación de la batería",
        "zh-Hans": "电池衰减趋势",
        "ja": "バッテリー劣化傾向",
        "nb": "Batteridegraderingstrend",
        "th": "แนวโน้มการเสื่อมสภาพของแบตเตอรี่"
    },
    "Battery Health": {
        "en": "Battery Health",
        "de": "Batteriegesundheit",
        "fr": "Santé de la batterie",
        "es": "Salud de la batería",
        "zh-Hans": "电池健康",
        "ja": "バッテリー健全度",
        "nb": "Batterihelse",
        "th": "สุขภาพแบตเตอรี่"
    },
    "Battery Health Grade": {
        "en": "Battery Health Grade",
        "de": "Batteriegesundheitsnote",
        "fr": "Note de santé de la batterie",
        "es": "Calificación de salud de batería",
        "zh-Hans": "电池健康评级",
        "ja": "バッテリー健全度グレード",
        "nb": "Batterihelsegrad",
        "th": "เกรดสุขภาพแบตเตอรี่"
    },
    "Battery Health Score": {
        "en": "Battery Health Score",
        "de": "Batteriegesundheitswert",
        "fr": "Score de santé de la batterie",
        "es": "Puntuación de salud de batería",
        "zh-Hans": "电池健康评分",
        "ja": "バッテリー健全度スコア",
        "nb": "Batterihelsescore",
        "th": "คะแนนสุขภาพแบตเตอรี่"
    },
    "Battery Longevity Impact": {
        "en": "Battery Longevity Impact",
        "de": "Auswirkung auf Batterielebensdauer",
        "fr": "Impact sur la longévité de la batterie",
        "es": "Impacto en longevidad de batería",
        "zh-Hans": "对电池寿命的影响",
        "ja": "バッテリー寿命への影響",
        "nb": "Effekt på batterilevetid",
        "th": "ผลกระทบต่ออายุการใช้งานแบตเตอรี่"
    },
    "Battery Longevity Principles": {
        "en": "Battery Longevity Principles",
        "de": "Grundsätze für Batterielanglebigkeit",
        "fr": "Principes de longévité de la batterie",
        "es": "Principios de longevidad de batería",
        "zh-Hans": "电池长寿养护准则",
        "ja": "バッテリー長寿命化の原則",
        "nb": "Prinsipper for batterilevetid",
        "th": "หลักการยืดอายุการใช้งานแบตเตอรี่"
    },
    "Battery SoC (%)": {
        "en": "Battery SoC (%)",
        "de": "Batterieladestand SoC (%)",
        "fr": "SoC de la batterie (%)",
        "es": "SoC de batería (%)",
        "zh-Hans": "电池电量 SoC (%)",
        "ja": "バッテリー SoC (%)",
        "nb": "Batteri-SoC (%)",
        "th": "ระดับแบตเตอรี่ SoC (%)"
    },
    "Battery Specifications": {
        "en": "Battery Specifications",
        "de": "Batteriespezifikationen",
        "fr": "Spécifications de la batterie",
        "es": "Especificaciones de batería",
        "zh-Hans": "电池规格",
        "ja": "バッテリースペック",
        "nb": "Batterispesifikasjoner",
        "th": "ข้อมูลจำเพาะแบตเตอรี่"
    },
    "Battery Wear by Distance": {
        "en": "Battery Wear by Distance",
        "de": "Batterieverschleiß nach Distanz",
        "fr": "Usure de la batterie par distance",
        "es": "Desgaste de batería por distancia",
        "zh-Hans": "里程相关电池损耗",
        "ja": "走行距離別バッテリー損耗",
        "nb": "Batterislitasje etter distanse",
        "th": "การสึกหรอของแบตเตอรี่ตามระยะทาง"
    },
    "Best Practices": {
        "en": "Best Practices",
        "de": "Empfehlungen",
        "fr": "Bonnes pratiques",
        "es": "Mejores prácticas",
        "zh-Hans": "最佳使用建议",
        "ja": "ベストプラクティス",
        "nb": "Beste praksis",
        "th": "ข้อแนะนำการใช้งาน"
    },
    "Booking Fee": {
        "en": "Booking Fee",
        "de": "Reservierungsgebühr",
        "fr": "Frais de réservation",
        "es": "Tarifa de reserva",
        "zh-Hans": "预约占位费",
        "ja": "予約手数料",
        "nb": "Reservasjonsgebyr",
        "th": "ค่าจองหัวชาร์จ"
    },
    "Calculated from depth of discharge, charging speeds, and target SoC consistency.": {
        "en": "Calculated from depth of discharge, charging speeds, and target SoC consistency.",
        "de": "Berechnet aus Entladetiefe, Ladegeschwindigkeiten und Ziel-SoC-Beständigkeit.",
        "fr": "Calculé à partir de la profondeur de décharge, des vitesses de charge et de la régularité du SoC cible.",
        "es": "Calculado a partir de profundidad de descarga, velocidades de carga y consistencia del SoC objetivo.",
        "zh-Hans": "根据放电深度、充电功率及目标电量控制规律综合评估计算。",
        "ja": "放電深度、充電速度、目標 SoC の一貫性から総合的に算出されます。",
        "nb": "Beregnet fra utladingsdybde, ladehastigheter og konsistens på mål-SoC.",
        "th": "คำนวณจากระดับความลึกของการคายประจุ ความเร็วในการชาร์จ และความสม่ำเสมอของระดับแบตเตอรี่เป้าหมาย"
    },
    "Calibrating": {
        "en": "Calibrating",
        "de": "Kalibriert…",
        "fr": "Calibrage…",
        "es": "Calibrando…",
        "zh-Hans": "校准中",
        "ja": "測定校正中",
        "nb": "Kalibrerer…",
        "th": "กำลังประเมินผล"
    },
    "Cancel": {
        "en": "Cancel",
        "de": "Abbrechen",
        "fr": "Annuler",
        "es": "Cancelar",
        "zh-Hans": "取消",
        "ja": "キャンセル",
        "nb": "Avbryt",
        "th": "ยกเลิก"
    },
    "Car Model Preset": {
        "en": "Car Model Preset",
        "de": "Fahrzeugmodell-Voreinstellung",
        "fr": "Préréglage du modèle de voiture",
        "es": "Preajuste de modelo de vehículo",
        "zh-Hans": "预设车型",
        "ja": "車種プリセット",
        "nb": "Forhåndsinnstilt bilmodell",
        "th": "พรีเซ็ตรุ่นรถ EV"
    },
    "Charged at Home": {
        "en": "Charged at Home",
        "de": "Zuhause geladen",
        "fr": "Rechargé à domicile",
        "es": "Cargado en casa",
        "zh-Hans": "在家充电",
        "ja": "自宅で充電",
        "nb": "Ladet hjemme",
        "th": "ชาร์จที่บ้าน"
    },
    "Charging Behavior & Battery Care": {
        "comment": "A heading for the charging behavior and battery care section of the battery health view.",
        "en": "Charging Behavior & Battery Care",
        "de": "Ladeverhalten & Batteriepflege",
        "fr": "Comportement de recharge et soin de la batterie",
        "es": "Comportamiento de carga y cuidado de batería",
        "zh-Hans": "充电习惯与电池维护",
        "ja": "充電習慣とバッテリーケア",
        "nb": "Ladeatferd og batteripleie",
        "th": "พฤติกรรมการชาร์จและการดูแลแบตเตอรี่"
    },
    "Charging Best Practices": {
        "en": "Charging Best Practices",
        "de": "Beste Ladepraktiken",
        "fr": "Bonnes pratiques de recharge",
        "es": "Mejores prácticas de carga",
        "zh-Hans": "最佳充电养护指南",
        "ja": "充電のベストプラクティス",
        "nb": "Beste ladepraksis",
        "th": "แนวทางปฏิบัติการชาร์จที่ดีที่สุด"
    },
    "Charging Details": {
        "en": "Charging Details",
        "de": "Ladedetails",
        "fr": "Détails de la recharge",
        "es": "Detalles de la carga",
        "zh-Hans": "充电详情",
        "ja": "充電詳細",
        "nb": "Ladedetaljer",
        "th": "รายละเอียดการชาร์จ"
    },
    "Charging Efficiencies": {
        "en": "Charging Efficiencies",
        "de": "Ladeeffizienzen",
        "fr": "Rendements de charge",
        "es": "Eficiencias de carga",
        "zh-Hans": "充电转换效率",
        "ja": "充電変換効率",
        "nb": "Ladeeffektiviteter",
        "th": "ประสิทธิภาพการแปลงพลังงาน"
    },
    "Charging Fee": {
        "en": "Charging Fee",
        "de": "Ladegebühr",
        "fr": "Frais de recharge",
        "es": "Tarifa de carga",
        "zh-Hans": "充电电费",
        "ja": "充電料金",
        "nb": "Ladegebyr",
        "th": "ค่าชาร์จ"
    },
    "Charging Habits": {
        "en": "Charging Habits",
        "de": "Ladegewohnheiten",
        "fr": "Habitudes de recharge",
        "es": "Hábitos de carga",
        "zh-Hans": "充电习惯",
        "ja": "充電傾向",
        "nb": "Ladevaner",
        "th": "พฤติกรรมการชาร์จ"
    },
    "Charging Parameters": {
        "en": "Charging Parameters",
        "de": "Ladeparameter",
        "fr": "Paramètres de recharge",
        "es": "Parámetros de carga",
        "zh-Hans": "充电参数",
        "ja": "充電パラメーター",
        "nb": "Ladeparametere",
        "th": "พารามิเตอร์การชาร์จ"
    },
    "Charging Power": {
        "en": "Charging Power",
        "de": "Ladeleistung",
        "fr": "Puissance de charge",
        "es": "Potencia de carga",
        "zh-Hans": "充电功率",
        "ja": "充電出力",
        "nb": "Ladeeffekt",
        "th": "กำลังไฟที่ชาร์จ"
    },
    "Charging Type": {
        "en": "Charging Type",
        "de": "Ladetyp",
        "fr": "Type de recharge",
        "es": "Tipo de carga",
        "zh-Hans": "充电类型",
        "ja": "充電タイプ",
        "nb": "Ladetype",
        "th": "ประเภทการชาร์จ"
    },
    "Charging on %@ saved you %@ this month compared to peak daytime rates (%@ kWh logged).": {
        "en": "Charging on %1$@ saved you %2$@ this month compared to peak daytime rates (%3$@ kWh logged).",
        "de": "Das Laden mit %1$@ hat Ihnen diesen Monat %2$@ gegenüber Spitzenzeiten erspart (%3$@ kWh geladen).",
        "fr": "Recharger avec %1$@ vous a fait économiser %2$@ ce mois-ci par rapport aux heures pleines (%3$@ kWh enregistrés).",
        "es": "Cargar con %1$@ te ahorró %2$@ este mes en comparación con tarifas pico (%3$@ kWh registrados).",
        "zh-Hans": "本月使用 %1$@ 充电相比白天高峰期电价为您节省了 %2$@ (共记录 %3$@ kWh)。",
        "ja": "%1$@ での充電により、日中ピーク料金と比較して今月 %2$@ の節約になりました (記録電力量: %3$@ kWh)。",
        "nb": "Lading med %1$@ sparte deg for %2$@ denne måneden sammenlignet med topppriser (%3$@ kWh logget).",
        "th": "การชาร์จด้วย %1$@ ช่วยคุณประหยัด %2$@ ในเดือนนี้เมื่อเทียบกับช่วง Peak (ชาร์จไป %3$@ kWh)"
    },
    "Choose Photo from Library": {
        "en": "Choose Photo from Library",
        "de": "Foto aus Mediathek wählen",
        "fr": "Choisir une photo dans la photothèque",
        "es": "Elegir foto de la biblioteca",
        "zh-Hans": "从相册选取照片",
        "ja": "ライブラリから写真を選択",
        "nb": "Velg bilde fra bibliotek",
        "th": "เลือกรูปจากคลังภาพ"
    },
    "Choose a charging session from the list to see its details.": {
        "comment": "A description of the action to take.",
        "en": "Choose a charging session from the list to see its details.",
        "de": "Wählen Sie einen Ladevorgang aus der Liste, um Details anzuzeigen.",
        "fr": "Choisissez une session de recharge dans la liste pour voir ses détails.",
        "es": "Elige una sesión de carga de la lista para ver sus detalles.",
        "zh-Hans": "从列表中选择一条充电记录以查看详细信息。",
        "ja": "リストから充電セッションを選択して詳細を表示します。",
        "nb": "Velg en ladeøkt fra listen for å se detaljene.",
        "th": "เลือกรายการชาร์จจากรายการเพื่อดูรายละเอียด"
    },
    "Choose an EV preset or customize your vehicle's specific configuration below.": {
        "en": "Choose an EV preset or customize your vehicle's specific configuration below.",
        "de": "Wählen Sie ein Elektrofahrzeug-Profil oder passen Sie die Konfiguration unten an.",
        "fr": "Choisissez un préréglage de VE ou personnalisez la configuration ci-dessous.",
        "es": "Elige un preajuste de VE o personaliza la configuración a continuación.",
        "zh-Hans": "选择预设电动车型或在下方自定义您的车辆参数配置。",
        "ja": "EV プリセットを選択するか、以下で詳細設定をカスタマイズしてください。",
        "nb": "Velg en forhåndsinnstilling eller tilpass kjøretøyets konfigurasjon nedenfor.",
        "th": "เลือกพรีเซ็ตรถยนต์ไฟฟ้า หรือปรับแต่งการกำหนดค่าเฉพาะของรถคุณด้านล่าง"
    },
    "Clean Up": {
        "en": "Clean Up",
        "de": "Bereinigen",
        "fr": "Nettoyer",
        "es": "Limpiar",
        "zh-Hans": "清理",
        "ja": "整理",
        "nb": "Rydd opp",
        "th": "ล้างข้อมูล"
    },
    "Clean Up Duplicate Sessions": {
        "en": "Clean Up Duplicate Sessions",
        "de": "Doppelte Ladevorgänge bereinigen",
        "fr": "Nettoyer les sessions en double",
        "es": "Limpiar sesiones duplicadas",
        "zh-Hans": "清理重复充电记录",
        "ja": "重複した充電セッションを整理",
        "nb": "Rydd opp i dupliserte ladeøkter",
        "th": "ล้างรายการชาร์จที่ซ้ำกัน"
    },
    "Clean Up Duplicates (%@)": {
        "en": "Clean Up Duplicates (%1$@)",
        "de": "Duplikate bereinigen (%1$@)",
        "fr": "Nettoyer les doublons (%1$@)",
        "es": "Limpiar duplicados (%1$@)",
        "zh-Hans": "清理重复项 (%1$@)",
        "ja": "重複を整理 (%1$@)",
        "nb": "Rydd opp i duplikater (%1$@)",
        "th": "ล้างรายการซ้ำ (%1$@)"
    },
    "Cloud Sync & Storage": {
        "en": "Cloud Sync & Storage",
        "de": "Cloud-Synchronisierung & Speicher",
        "fr": "Synchronisation et stockage cloud",
        "es": "Sincronización y almacenamiento en la nube",
        "zh-Hans": "云端同步与存储",
        "ja": "クラウド同期とストレージ",
        "nb": "Skysynkronisering og lagring",
        "th": "การซิงค์และจัดเก็บบนคลาวด์"
    },
    "Cloud Sync Active": {
        "en": "Cloud Sync Active",
        "de": "Cloud-Synchronisierung aktiv",
        "fr": "Synchronisation cloud active",
        "es": "Sincronización en la nube activa",
        "zh-Hans": "云端同步已开启",
        "ja": "クラウド同期中",
        "nb": "Skysynkronisering aktiv",
        "th": "ซิงค์คลาวด์ทำงานอยู่"
    },
    "Compact SUV / Crossover": {
        "en": "Compact SUV / Crossover",
        "de": "Kompakt-SUV / Crossover",
        "fr": "SUV compact / Crossover",
        "es": "SUV compacto / Crossover",
        "zh-Hans": "紧凑型 SUV / 跨界车",
        "ja": "コンパクトSUV / クロスオーバー",
        "nb": "Kompakt SUV / Crossover",
        "th": "SUV ขนาดกะทัดรัด / ครอสโอเวอร์"
    },
    "Compact Sedan / Eco Car": {
        "en": "Compact Sedan / Eco Car",
        "de": "Kompaktlimousine / Kleinwagen",
        "fr": "Berline compacte / Citadine éco",
        "es": "Sedán compacto / Auto ecológico",
        "zh-Hans": "紧凑型轿车 / 节能小型车",
        "ja": "コンパクトセダン / エコカー",
        "nb": "Kompakt sedan / småbil",
        "th": "รถเก๋งขนาดเล็ก / อีโคคาร์"
    },
    "Compact Sedan / Hatchback": {
        "en": "Compact Sedan / Hatchback",
        "de": "Kompaktlimousine / Schrägheck",
        "fr": "Berline compacte / Hayon",
        "es": "Sedán compacto / Hatchback",
        "zh-Hans": "紧凑型轿车 / 两厢车",
        "ja": "コンパクトセダン / ハッチバック",
        "nb": "Kompakt sedan / kombi",
        "th": "รถเก๋งเล็ก / แฮทช์แบ็ก"
    },
    "Cost Efficiency": {
        "en": "Cost Efficiency",
        "de": "Kosteneffizienz",
        "fr": "Efficacité des coûts",
        "es": "Eficiencia de costos",
        "zh-Hans": "成本效益",
        "ja": "費用対効果",
        "nb": "Kostnadseffektivitet",
        "th": "ราคาเฉลี่ยต่อหน่วย"
    },
    "Cost Savings vs Gas: %@ saved (%@), %@ fuel avoided": {
        "en": "Cost Savings vs Gas: %1$@ saved (%2$@), %3$@ fuel avoided",
        "de": "Kostenersparnis vs. Benzin: %1$@ gespart (%2$@), %3$@ Kraftstoff vermieden",
        "fr": "Économies vs essence : %1$@ économisés (%2$@), %3$@ de carburant évités",
        "es": "Ahorro vs. gasolina: %1$@ ahorrado (%2$@), %3$@ de combustible evitado",
        "zh-Hans": "对比燃油花费节省：%1$@ (%2$@)，避免消耗 %3$@ 燃油",
        "ja": "ガソリン比節約額: %1$@ 節約 (%2$@), ガソリン %3$@ 削減",
        "nb": "Kostnadsbesparelse vs. bensin: %1$@ spart (%2$@), %3$@ drivstoff spart",
        "th": "ประหยัดค่าใช้จ่ายเทียบกับรถน้ำมัน: ประหยัด %1$@ (%2$@), ลดการใช้น้ำมัน %3$@"
    },
    "Cost Savings vs Gas: Saved %@, gas equivalent %@": {
        "en": "Cost Savings vs Gas: Saved %1$@, gas equivalent %2$@",
        "de": "Kostenersparnis vs. Benzin: %1$@ gespart, Benzinäquivalent %2$@",
        "fr": "Économies vs essence : %1$@ économisés, équivalent essence %2$@",
        "es": "Ahorro vs. gasolina: Ahorrado %1$@, equivalente en gasolina %2$@",
        "zh-Hans": "对比燃油花费节省：已省 %1$@，燃油等效费用 %2$@",
        "ja": "ガソリン比節約額: 節約 %1$@, ガソリン換算 %2$@",
        "nb": "Besparelse vs. bensin: Spart %1$@, bensinekvivalent %2$@",
        "th": "ประหยัดค่าใช้จ่ายเทียบกับรถน้ำมัน: ประหยัดได้ %1$@, เทียบเท่าน้ำมัน %2$@"
    },
    "Cost Savings vs. Gas": {
        "en": "Cost Savings vs. Gas",
        "de": "Kostenersparnis vs. Benzin",
        "fr": "Économies par rapport à l'essence",
        "es": "Ahorro de costos vs. gasolina",
        "zh-Hans": "对比燃油节省金额",
        "ja": "ガソリン比節約額",
        "nb": "Kostnadsbesparelse vs. bensin",
        "th": "ประหยัดค่าใช้จ่ายเทียบกับรถน้ำมัน"
    },
    "Cost This Month": {
        "en": "Cost This Month",
        "de": "Kosten diesen Monat",
        "fr": "Coût ce mois-ci",
        "es": "Costo este mes",
        "zh-Hans": "本月花费",
        "ja": "今月の充電費用",
        "nb": "Kostnad denne måneden",
        "th": "ค่าใช้จ่ายเดือนนี้"
    },
    "Currency": {
        "en": "Currency",
        "de": "Währung",
        "fr": "Devise",
        "es": "Moneda",
        "zh-Hans": "货币",
        "ja": "通貨",
        "nb": "Valuta",
        "th": "สกุลเงิน"
    },
    "Custom": {
        "en": "Custom",
        "de": "Benutzerdefiniert",
        "fr": "Personnalisé",
        "es": "Personalizado",
        "zh-Hans": "自定义",
        "ja": "カスタム",
        "nb": "Egendefinert",
        "th": "กำหนดเอง"
    },
    "Custom Baseline": {
        "en": "Custom Baseline",
        "de": "Benutzerdefinierte Basis",
        "fr": "Référence personnalisée",
        "es": "Línea base personalizada",
        "zh-Hans": "自定义基准",
        "ja": "カスタム基準",
        "nb": "Egendefinert referanse",
        "th": "กำหนดเกณฑ์เอง"
    },
    "Custom Electricity Rate": {
        "en": "Custom Electricity Rate",
        "de": "Eigener Strompreis",
        "fr": "Tarif d'électricité personnalisé",
        "es": "Tarifa eléctrica personalizada",
        "zh-Hans": "自定义电价",
        "ja": "カスタム電気料金",
        "nb": "Egendefinert strømpris",
        "th": "อัตราค่าไฟกำหนดเอง"
    },
    "Custom Tariff Rate": {
        "en": "Custom Tariff Rate",
        "de": "Individueller Strompreis",
        "fr": "Tarif personnalisé",
        "es": "Tarifa personalizada",
        "zh-Hans": "自定义电价",
        "ja": "カスタム電気料金単価",
        "nb": "Egendefinert tariffsats",
        "th": "กำหนดอัตราค่าไฟเอง"
    },
    "Cycle Life to 80% SoH": {
        "en": "Cycle Life to 80% SoH",
        "de": "Zyklenlebensdauer bis 80 % SoH",
        "fr": "Cycles de vie jusqu'à 80 % SoH",
        "es": "Ciclos de vida hasta 80% SoH",
        "zh-Hans": "至 80% 健康度的循环寿命",
        "ja": "80% SoH までのサイクル寿命",
        "nb": "Sykluslevetid til 80 % SoH",
        "th": "อายุรอบชาร์จจนถึง SoH 80%"
    },
    "Cycle Wear": {
        "en": "Cycle Wear",
        "de": "Zyklusabnutzung",
        "fr": "Usure par cycles",
        "es": "Desgaste por ciclos",
        "zh-Hans": "循环损耗",
        "ja": "サイクル摩耗",
        "nb": "Syklusslitasje",
        "th": "การเสื่อมของรอบชาร์จ"
    },
    "cycles": {
        "en": "cycles",
        "de": "Zyklen",
        "fr": "cycles",
        "es": "ciclos",
        "zh-Hans": "次循环",
        "ja": "サイクル",
        "nb": "sykluser",
        "th": "รอบชาร์จ"
    },
    "DC": {
        "en": "DC",
        "de": "DC",
        "fr": "DC",
        "es": "CC",
        "zh-Hans": "直流 (DC)",
        "ja": "急速充電 (DC)",
        "nb": "DC",
        "th": "DC"
    },
    "DC Efficiency": {
        "en": "DC Efficiency",
        "de": "DC-Wirkungsgrad",
        "fr": "Efficacité DC",
        "es": "Eficiencia CC",
        "zh-Hans": "直流充电效率",
        "ja": "急速充電 (DC) 効率",
        "nb": "DC-effektivitet",
        "th": "ประสิทธิภาพ DC"
    },
    "DC Fast": {
        "en": "DC Fast",
        "de": "DC-Schnellladen",
        "fr": "Recharge rapide DC",
        "es": "Carga rápida CC",
        "zh-Hans": "直流快充",
        "ja": "急速充電",
        "nb": "DC-hurtiglading",
        "th": "DC ชาร์จเร็ว"
    },
    "DC Fast Charge Efficiency": {
        "en": "DC Fast Charge Efficiency",
        "de": "DC-Schnellladeeffizienz",
        "fr": "Efficacité de charge rapide DC",
        "es": "Eficiencia de carga rápida CC",
        "zh-Hans": "直流快充效率",
        "ja": "急速充電 (DC) 効率",
        "nb": "DC-hurtigladeeffektivitet",
        "th": "ประสิทธิภาพการชาร์จ DC"
    },
    "DC Fast Efficiency": {
        "en": "DC Fast Efficiency",
        "de": "DC-Schnellladeeffizienz",
        "fr": "Efficacité de recharge rapide DC",
        "es": "Eficiencia de carga rápida CC",
        "zh-Hans": "直流快充效率",
        "ja": "急速充電効率",
        "nb": "DC-hurtigladeeffektivitet",
        "th": "ประสิทธิภาพ DC Fast Charge"
    },
    "Dark": {
        "en": "Dark",
        "de": "Dunkel",
        "fr": "Sombre",
        "es": "Oscuro",
        "zh-Hans": "深色",
        "ja": "ダーク",
        "nb": "Mørk",
        "th": "มืด"
    },
    "Dashboard": {
        "en": "Dashboard",
        "de": "Übersicht",
        "fr": "Tableau de bord",
        "es": "Panel",
        "zh-Hans": "仪表盘",
        "ja": "ダッシュボード",
        "nb": "Oversikt",
        "th": "หน้าหลัก"
    },
    "Date & Time": {
        "en": "Date & Time",
        "de": "Datum & Uhrzeit",
        "fr": "Date et heure",
        "es": "Fecha y hora",
        "zh-Hans": "日期与时间",
        "ja": "日時",
        "nb": "Dato og tid",
        "th": "วันและเวลา"
    },
    "Deep Discharge Zone (Start < 15%)": {
        "comment": "A warning label for a battery that is starting below 15% charge.",
        "en": "Deep Discharge Zone (Start < 15%)",
        "de": "Tiefentladungszone (Start < 15 %)",
        "fr": "Zone de décharge profonde (Début < 15 %)",
        "es": "Zona de descarga profunda (Inicio < 15%)",
        "zh-Hans": "深度放电区 (起始 < 15%)",
        "ja": "深放電ゾーン (開始時 < 15%)",
        "nb": "Dyp utladingssone (Start < 15 %)",
        "th": "โซนคายประจุลึก (เริ่มต้น < 15%)"
    },
    "Default": {
        "comment": "A label for a badge that indicates a vehicle is the default.",
        "en": "Default",
        "de": "Standard",
        "fr": "Par défaut",
        "es": "Predeterminado",
        "zh-Hans": "默认",
        "ja": "デフォルト",
        "nb": "Standard",
        "th": "ค่าเริ่มต้น"
    },
    "Deferred to Bill This Month": {
        "en": "Deferred to Bill This Month",
        "de": "Diesen Monat auf Stromrechnung",
        "fr": "Reporté sur la facture ce mois-ci",
        "es": "Diferido a la factura este mes",
        "zh-Hans": "本月计入电费账单",
        "ja": "今月の電気代請求に計上",
        "nb": "Overført til strømregning denne måneden",
        "th": "รวมในบิลค่าไฟเดือนนี้"
    },
    "Deferred to your electric bill.": {
        "en": "Deferred to your electric bill.",
        "de": "Wird über Ihre Stromrechnung abgerechnet.",
        "fr": "Reporté sur votre facture d'électricité.",
        "es": "Diferido a tu factura de electricidad.",
        "zh-Hans": "计入家庭电费账单。",
        "ja": "電気料金請求に計上されます。",
        "nb": "Overføres til strømregningen din.",
        "th": "รวมในบิลค่าไฟฟ้าของคุณ"
    },
    "Degradation Rate": {
        "en": "Degradation Rate",
        "de": "Degradationsrate",
        "fr": "Taux de dégradation",
        "es": "Tasa de degradación",
        "zh-Hans": "电池衰减率",
        "ja": "劣化率",
        "nb": "Degraderingsrate",
        "th": "อัตราการเสื่อมสภาพ"
    },
    "Degradation rate still calibrating — log more charges with start and end %.": {
        "en": "Degradation rate still calibrating — log more charges with start and end %.",
        "de": "Degradationsrate wird noch kalibriert — erfassen Sie mehr Ladevorgänge mit Start- und End-%.",
        "fr": "Taux de dégradation en cours d'étalonnage — enregistrez plus de recharges avec % début et fin.",
        "es": "Tasa de degradación en calibración: registra más cargas con % inicial y final.",
        "zh-Hans": "衰减率仍在校准中 — 请记录更多包含起始与结束电量百分比的充电数据。",
        "ja": "劣化率の測定中 — 開始・終了％を含む充電記録をさらに追加してください。",
        "nb": "Degraderingsrate kalibreres fortsatt — logg flere ladinger med start- og slutt-%.",
        "th": "กำลังประเมินอัตราการเสื่อม — บันทึกการชาร์จที่มี % แบตเตอรี่เริ่มต้นและสิ้นสุดเพิ่มเติม"
    },
    "Delete": {
        "en": "Delete",
        "de": "Löschen",
        "fr": "Supprimer",
        "es": "Eliminar",
        "zh-Hans": "删除",
        "ja": "削除",
        "nb": "Slett",
        "th": "ลบ"
    },
    "Delete \"%@\"": {
        "en": "Delete \"%1$@\"",
        "de": "„%1$@“ löschen",
        "fr": "Supprimer « %1$@ »",
        "es": "Eliminar \"%1$@\"",
        "zh-Hans": "删除“%1$@”",
        "ja": "「%1$@」を削除",
        "nb": "Slett «%1$@»",
        "th": "ลบ \"%1$@\""
    },
    "Delete Session": {
        "en": "Delete Session",
        "de": "Ladevorgang löschen",
        "fr": "Supprimer la session",
        "es": "Eliminar sesión",
        "zh-Hans": "删除记录",
        "ja": "セッションを削除",
        "nb": "Slett økt",
        "th": "ลบรายการชาร์จ"
    },
    "Details": {
        "comment": "A label for a button that opens a detailed view.",
        "en": "Details",
        "de": "Details",
        "fr": "Détails",
        "es": "Detalles",
        "zh-Hans": "详情",
        "ja": "詳細",
        "nb": "Detaljer",
        "th": "รายละเอียด"
    },
    "Deterioration Trends": {
        "en": "Deterioration Trends",
        "de": "Verschleißtrends",
        "fr": "Tendances de détérioration",
        "es": "Tendencias de deterioro",
        "zh-Hans": "衰减趋势",
        "ja": "劣化傾向",
        "nb": "Degraderingstrender",
        "th": "แนวโน้มการเสื่อมสภาพ"
    },
    "Display Name": {
        "en": "Display Name",
        "de": "Anzeigename",
        "fr": "Nom d'affichage",
        "es": "Nombre para mostrar",
        "zh-Hans": "显示名称",
        "ja": "表示名",
        "nb": "Visningsnavn",
        "th": "ชื่อที่แสดง"
    },
    "Distance": {
        "en": "Distance",
        "de": "Distanz",
        "fr": "Distance",
        "es": "Distancia",
        "zh-Hans": "行驶距离",
        "ja": "距離",
        "nb": "Avstand",
        "th": "ระยะทาง"
    },
    "Distance Unit": {
        "en": "Distance Unit",
        "de": "Entfernungseinheit",
        "fr": "Unité de distance",
        "es": "Unidad de distancia",
        "zh-Hans": "距离单位",
        "ja": "距離の単位",
        "nb": "Avstandsenhet",
        "th": "หน่วยระยะทาง"
    },
    "Done": {
        "en": "Done",
        "de": "Fertig",
        "fr": "Terminé",
        "es": "Listo",
        "zh-Hans": "完成",
        "ja": "完了",
        "nb": "Ferdig",
        "th": "เสร็จสิ้น"
    },
    "Driving Cost": {
        "en": "Driving Cost",
        "de": "Fahrtkosten",
        "fr": "Coût de conduite",
        "es": "Costo de conducción",
        "zh-Hans": "行车成本",
        "ja": "走行コスト",
        "nb": "Kjørekostnad",
        "th": "ต้นทุนการขับขี่"
    },
    "Driving Eff.": {
        "en": "Driving Eff.",
        "de": "Verbrauch",
        "fr": "Eff. de conduite",
        "es": "Efic. de conducción",
        "zh-Hans": "行驶能效",
        "ja": "走行電費",
        "nb": "Kjøreeff.",
        "th": "ประสิทธิภาพการขับขี่"
    },
    "Duplicate Check": {
        "en": "Duplicate Check",
        "de": "Duplikatsprüfung",
        "fr": "Vérification des doublons",
        "es": "Comprobación de duplicados",
        "zh-Hans": "查重",
        "ja": "重複チェック",
        "nb": "Duplikatsjekk",
        "th": "ตรวจสอบรายการซ้ำ"
    },
    "Duration": {
        "en": "Duration",
        "de": "Dauer",
        "fr": "Durée",
        "es": "Duración",
        "zh-Hans": "充电时长",
        "ja": "所要時間",
        "nb": "Varighet",
        "th": "ระยะเวลา"
    },
    "EV Spent": {
        "en": "EV Spent",
        "de": "EV-Kosten",
        "fr": "Dépensé en VE",
        "es": "Gasto en VE",
        "zh-Hans": "电动车电费",
        "ja": "EV充電支出",
        "nb": "Elbil-forbruk",
        "th": "ค่าไฟ EV ที่จ่าย"
    },
    "EV battery degradation is driven by four primary stressors: high cell temperature, extreme State of Charge (>90% or <10%), high charging current (DC fast charge C-rate), and time spent at high voltage. Follow these proven practices to maximize pack life and resale value.": {
        "comment": "A description of the benefits of following battery longevity best practices.",
        "en": "EV battery degradation is driven by four primary stressors: high cell temperature, extreme State of Charge (>90% or <10%), high charging current (DC fast charge C-rate), and time spent at high voltage. Follow these proven practices to maximize pack life and resale value.",
        "de": "Die Alterung von EV-Batterien wird durch vier Hauptfaktoren beschleunigt: hohe Zelltemperatur, extreme Ladezustände (>90 % oder <10 %), hohe Ladeströme (DC-Schnellladen) und Verweildauer bei hoher Spannung. Beachten Sie diese bewährten Regeln, um Lebensdauer und Wiederverkaufswert zu maximieren.",
        "fr": "La dégradation de la batterie d'un VE est causée par quatre facteurs majeurs : température élevée, état de charge extrême (>90 % ou <10 %), fort courant de charge (recharge rapide DC) et maintien prolongé à haute tension. Suivez ces conseils pour maximiser sa durée de vie et sa valeur de revente.",
        "es": "La degradación de la batería de un VE se debe a cuatro factores principales: alta temperatura, estado de carga extremo (>90% o <10%), alta corriente de carga rápida y tiempo prolongado a alto voltaje. Sigue estas prácticas para maximizar la vida útil y el valor de reventa.",
        "zh-Hans": "电动汽车动力电池衰减主要由四大压力因素导致：高温、极端电量区间（高于 90% 或低于 10%）、高倍率直流快充大电流，以及长时间处于高电压状态。遵循这些科学保养建议可有效延长电池寿命并保持高残值。",
        "ja": "EVバッテリーの劣化は、高温、極端な充電状態（>90% または <10%）、急速充電の大電流、高電圧状態での放置という4つの主要因によって引き起こされます。これらのベストプラクティスを実践し、バッテリー寿命とリセールバリューを最大限に維持しましょう。",
        "nb": "Elbilbatteriets degradering drives av fire hovedfaktorer: høy celletemperatur, ekstreme ladenivåer (>90 % eller <10 %), høy ladestrøm (DC-hurtiglading) og tid tilbrakt ved høy spenning. Følg disse praksisene for å maksimere batterilevetid og bruktverdi.",
        "th": "การเสื่อมสภาพของแบตเตอรี่ EV เกิดจาก 4 ปัจจัยหลัก: อุณหภูมิเซลล์ที่สูง, ระดับแบตเตอรี่สุดขั้ว (>90% หรือ <10%), กระแสชาร์จ DC ที่สูง และการแช่แบตเตอรี่ไว้ที่แรงดันสูงเป็นเวลานาน ปฏิบัติตามคำแนะนำเหล่านี้เพื่อยืดอายุการใช้งานและรักษามูลค่าการขายต่อ"
    },
    "Edit": {
        "en": "Edit",
        "de": "Bearbeiten",
        "fr": "Modifier",
        "es": "Editar",
        "zh-Hans": "编辑",
        "ja": "編集",
        "nb": "Rediger",
        "th": "แก้ไข"
    },
    "Edit Session": {
        "en": "Edit Session",
        "de": "Ladevorgang bearbeiten",
        "fr": "Modifier la session",
        "es": "Editar sesión",
        "zh-Hans": "编辑记录",
        "ja": "セッションを編集",
        "nb": "Rediger ladeøkt",
        "th": "แก้ไขการชาร์จ"
    },
    "Edit…": {
        "en": "Edit…",
        "de": "Bearbeiten…",
        "fr": "Modifier…",
        "es": "Editar…",
        "zh-Hans": "编辑…",
        "ja": "編集…",
        "nb": "Rediger…",
        "th": "แก้ไข…"
    },
    "Efficiency": {
        "en": "Efficiency",
        "de": "Effizienz",
        "fr": "Efficacité",
        "es": "Eficiencia",
        "zh-Hans": "能效",
        "ja": "電費効率",
        "nb": "Effektivitet",
        "th": "ความคุ้มค่า"
    },
    "Efficiency Unit": {
        "en": "Efficiency Unit",
        "de": "Effizienzeinheit",
        "fr": "Unité d'efficacité",
        "es": "Unidad de eficiencia",
        "zh-Hans": "能耗单位",
        "ja": "電費の単位",
        "nb": "Effektivitetsenhet",
        "th": "หน่วยวัดอัตราสิ้นเปลือง"
    },
    "Electricity Tariff": {
        "en": "Electricity Tariff",
        "de": "Stromtarif",
        "fr": "Tarif d'électricité",
        "es": "Tarifa eléctrica",
        "zh-Hans": "电价",
        "ja": "電気料金",
        "nb": "Strømtariff",
        "th": "อัตราค่าไฟฟ้า"
    },
    "End": {
        "en": "End",
        "de": "Ende",
        "fr": "Fin",
        "es": "Fin",
        "zh-Hans": "结束",
        "ja": "終了",
        "nb": "Slutt",
        "th": "สิ้นสุด"
    },
    "End Battery %": {
        "en": "End Battery %",
        "de": "End-Batteriestand %",
        "fr": "% de batterie final",
        "es": "% de batería final",
        "zh-Hans": "结束电量 %",
        "ja": "終了時バッテリー ％",
        "nb": "Sluttbatteri %",
        "th": "% แบตเตอรี่สิ้นสุด"
    },
    "Energy": {
        "en": "Energy",
        "de": "Energie",
        "fr": "Énergie",
        "es": "Energía",
        "zh-Hans": "电量",
        "ja": "電力量",
        "nb": "Energi",
        "th": "พลังงาน"
    },
    "Energy Added": {
        "en": "Energy Added",
        "de": "Geladene Energie",
        "fr": "Énergie ajoutée",
        "es": "Energía añadida",
        "zh-Hans": "充入电量",
        "ja": "充電電力量",
        "nb": "Energi tilført",
        "th": "พลังงานที่ชาร์จเข้า"
    },
    "Energy This Month": {
        "en": "Energy This Month",
        "de": "Energie diesen Monat",
        "fr": "Énergie ce mois-ci",
        "es": "Energía este mes",
        "zh-Hans": "本月充入电量",
        "ja": "今月の電力量",
        "nb": "Energi denne måneden",
        "th": "พลังงานเดือนนี้"
    },
    "Est. Pack Capacity": {
        "en": "Est. Pack Capacity",
        "de": "Geschätzte Batteriekapazität",
        "fr": "Capacité estimée du pack",
        "es": "Capacidad estimada del paquete",
        "zh-Hans": "预估电池容量",
        "ja": "推定バッテリー容量",
        "nb": "Beregnet batterikapasitet",
        "th": "ความจุแบตเตอรี่ประเมิน"
    },
    "Est. Range": {
        "en": "Est. Range",
        "de": "Geschätzte Reichweite",
        "fr": "Autonomie estimée",
        "es": "Autonomía estimada",
        "zh-Hans": "预估续航",
        "ja": "推定航続距離",
        "nb": "Beregnet rekkevidde",
        "th": "ระยะทางประเมิน"
    },
    "Estimated Range (%@)": {
        "en": "Estimated Range (%1$@)",
        "de": "Geschätzte Reichweite (%1$@)",
        "fr": "Autonomie estimée (%1$@)",
        "es": "Autonomía estimada (%1$@)",
        "zh-Hans": "预估续航 (%1$@)",
        "ja": "推定航続距離 (%1$@)",
        "nb": "Beregnet rekkevidde (%1$@)",
        "th": "ระยะทางประเมิน (%1$@)"
    },
    "Estimated Savings": {
        "en": "Estimated Savings",
        "de": "Geschätzte Ersparnis",
        "fr": "Économies estimées",
        "es": "Ahorro estimado",
        "zh-Hans": "预估节省金额",
        "ja": "推定節約額",
        "nb": "Beregnede besparelser",
        "th": "ยอดประหยัดโดยประมาณ"
    },
    "Estimated State of Health (SoH)": {
        "comment": "A label describing the estimated state of the battery.",
        "en": "Estimated State of Health (SoH)",
        "de": "Geschätzter Batteriezustand (SoH)",
        "fr": "État de santé estimé (SoH)",
        "es": "Estado de salud estimado (SoH)",
        "zh-Hans": "预估电池健康状态 (SoH)",
        "ja": "推定バッテリー健全度 (SoH)",
        "nb": "Beregnet batterihelse (SoH)",
        "th": "สุขภาพแบตเตอรี่โดยประมาณ (SoH)"
    },
    "Estimated from SoC delta based on %@ (%@ kWh nominal pack capacity).": {
        "en": "Estimated from SoC delta based on %1$@ (%2$@ kWh nominal pack capacity).",
        "de": "Geschätzt aus SoC-Differenz basierend auf %1$@ (%2$@ kWh Nennkapazität).",
        "fr": "Estimé à partir de la variation du SoC basée sur %1$@ (capacité nominale de %2$@ kWh).",
        "es": "Estimado a partir del diferencial de SoC basado en %1$@ (capacidad nominal de %2$@ kWh).",
        "zh-Hans": "根据 %1$@ 的电池 SoC 变化估算 (标称容量 %2$@ kWh)。",
        "ja": "%1$@ の SoC 変化量から推定 (公称パック容量 %2$@ kWh)。",
        "nb": "Beregnet fra SoC-differanse basert på %1$@ (%2$@ kWh nominell batterikapasitet).",
        "th": "คำนวณจากส่วนต่าง SoC โดยอิงตาม %1$@ (ความจุมาตรฐาน %2$@ kWh)"
    },
    "Estimated from SoC delta based on %@ (%.1f kWh @ %.0f%% efficiency, %.1f kW wall charger).": {
        "en": "Estimated from SoC delta based on %1$@ (%2$.1f kWh @ %3$.0f%% efficiency, %4$.1f kW wall charger).",
        "de": "Geschätzt aus SoC-Differenz basierend auf %1$@ (%2$.1f kWh bei %3$.0f %% Effizienz, %4$.1f kW Wallbox).",
        "fr": "Estimé d'après la variation du SoC basée sur %1$@ (%2$.1f kWh à %3$.0f %% d'efficacité, borne de %4$.1f kW).",
        "es": "Estimado del delta de SoC según %1$@ (%2$.1f kWh al %3$.0f%% de eficiencia, cargador de %4$.1f kW).",
        "zh-Hans": "根据 %1$@ 的 SoC 变化估算 (%2$.1f kWh，%3$.0f%% 效率，%4$.1f kW 家用充电桩)。",
        "ja": "%1$@ の SoC 変化量に基づき推定 (%2$.1f kWh、効率 %3$.0f%%、%4$.1f kW 充電器)。",
        "nb": "Beregnet fra SoC-differanse basert på %1$@ (%2$.1f kWh ved %3$.0f %% effektivitet, %4$.1f kW ladeboks).",
        "th": "คำนวณจากส่วนต่าง SoC โดยอิงตาม %1$@ (%2$.1f kWh ที่ประสิทธิภาพ %3$.0f%%, เครื่องชาร์จบ้าน %4$.1f kW)"
    },
    "Expected Cycle Life (80%)": {
        "en": "Expected Cycle Life (80%)",
        "de": "Erwartete Zyklenlebensdauer (80 %)",
        "fr": "Durée de vie prévue en cycles (80 %)",
        "es": "Ciclos de vida esperados (80%)",
        "zh-Hans": "预期循环寿命 (至 80%)",
        "ja": "期待サイクル寿命 (80%)",
        "nb": "Forventet sykluslevetid (80 %)",
        "th": "อายุรอบการชาร์จที่ 80%"
    },
    "Export All to CSV…": {
        "en": "Export All to CSV…",
        "de": "Alle als CSV exportieren…",
        "fr": "Tout exporter en CSV…",
        "es": "Exportar todo a CSV…",
        "zh-Hans": "全部导出为 CSV…",
        "ja": "すべて CSV にエクスポート…",
        "nb": "Eksporter alt til CSV…",
        "th": "ส่งออกทั้งหมดเป็น CSV…"
    },
    "Export CSV": {
        "en": "Export CSV",
        "de": "CSV exportieren",
        "fr": "Exporter en CSV",
        "es": "Exportar CSV",
        "zh-Hans": "导出 CSV",
        "ja": "CSV エクスポート",
        "nb": "Eksporter CSV",
        "th": "ส่งออก CSV"
    },
    "Export Reimbursement PDF…": {
        "en": "Export Reimbursement PDF…",
        "de": "Erstattungs-PDF exportieren…",
        "fr": "Exporter le PDF de remboursement…",
        "es": "Exportar PDF de reembolso…",
        "zh-Hans": "导出报销单 PDF…",
        "ja": "精算用 PDF を書き出す…",
        "nb": "Eksporter refusjons-PDF…",
        "th": "ส่งออก PDF สำหรับเบิกจ่าย…"
    },
    "Extracted Charging Values": {
        "comment": "A title for the section of the view that displays the scanned data.",
        "en": "Extracted Charging Values",
        "de": "Erkannte Ladewerte",
        "fr": "Valeurs de charge extraites",
        "es": "Valores de carga extraídos",
        "zh-Hans": "识别到的充电数据",
        "ja": "抽出された充電データ",
        "nb": "Uthentede ladeverdier",
        "th": "ข้อมูลการชาร์จที่ตรวจพบ"
    },
    "Factory %@ %@ (%@)": {
        "en": "Factory %1$@ %2$@ (%3$@)",
        "de": "Werk %1$@ %2$@ (%3$@)",
        "fr": "Usine %1$@ %2$@ (%3$@)",
        "es": "Fábrica %1$@ %2$@ (%3$@)",
        "zh-Hans": "出厂 %1$@ %2$@ (%3$@)",
        "ja": "出荷時公称 %1$@ %2$@ (%3$@)",
        "nb": "Fabrikk %1$@ %2$@ (%3$@)",
        "th": "ค่าโรงงาน %1$@ %2$@ (%3$@)"
    },
    "Factory Rated Range": {
        "en": "Factory Rated Range",
        "de": "Werksreichweite",
        "fr": "Autonomie nominale d'usine",
        "es": "Autonomía nominal de fábrica",
        "zh-Hans": "官方标称续航",
        "ja": "カタログ公称航続距離",
        "nb": "Fabrikkoppgitt rekkevidde",
        "th": "ระยะทางมาตรฐานจากโรงงาน"
    },
    "Fees (%@)": {
        "en": "Fees (%1$@)",
        "de": "Gebühren (%1$@)",
        "fr": "Frais (%1$@)",
        "es": "Tarifas (%1$@)",
        "zh-Hans": "附加费 (%1$@)",
        "ja": "追加料金 (%1$@)",
        "nb": "Gebyrer (%1$@)",
        "th": "ค่าบริการ (%1$@)"
    },
    "Fees Breakdown": {
        "en": "Fees Breakdown",
        "de": "Aufschlüsselung der Gebühren",
        "fr": "Détail des frais",
        "es": "Desglose de tarifas",
        "zh-Hans": "费用明细",
        "ja": "料金内訳",
        "nb": "Gebyrfordeling",
        "th": "รายละเอียดค่าบริการ"
    },
    "Filter": {
        "en": "Filter",
        "de": "Filtern",
        "fr": "Filtrer",
        "es": "Filtrar",
        "zh-Hans": "筛选",
        "ja": "フィルター",
        "nb": "Filter",
        "th": "ตัวกรอง"
    },
    "Filter Practices": {
        "en": "Filter Practices",
        "de": "Praktiken filtern",
        "fr": "Filtrer les pratiques",
        "es": "Filtrar prácticas",
        "zh-Hans": "筛选建议",
        "ja": "項目を絞り込む",
        "nb": "Filtrer praksis",
        "th": "กรองแนวทางปฏิบัติ"
    },
    "Free": {
        "en": "Free",
        "de": "Kostenlos",
        "fr": "Gratuit",
        "es": "Gratis",
        "zh-Hans": "免费",
        "ja": "無料",
        "nb": "Gratis",
        "th": "ฟรี"
    },
    "Free Charging": {
        "en": "Free Charging",
        "de": "Kostenloses Laden",
        "fr": "Recharge gratuite",
        "es": "Carga gratuita",
        "zh-Hans": "免费充电",
        "ja": "無料充電",
        "nb": "Gratis lading",
        "th": "ชาร์จฟรี"
    },
    "Fuel Avoided": {
        "en": "Fuel Avoided",
        "de": "Kraftstoff vermieden",
        "fr": "Carburant évité",
        "es": "Combustible evitado",
        "zh-Hans": "节省燃油",
        "ja": "削減燃料",
        "nb": "Drivstoff spart",
        "th": "ลดการใช้น้ำมัน"
    },
    "Fuel Economy": {
        "en": "Fuel Economy",
        "de": "Kraftstoffverbrauch",
        "fr": "Consommation de carburant",
        "es": "Consumo de combustible",
        "zh-Hans": "燃油油耗",
        "ja": "ガソリン燃費",
        "nb": "Drivstofføkonomi",
        "th": "อัตราสิ้นเปลืองน้ำมัน"
    },
    "Fuel Price": {
        "en": "Fuel Price",
        "de": "Kraftstoffpreis",
        "fr": "Prix du carburant",
        "es": "Precio del combustible",
        "zh-Hans": "油价",
        "ja": "燃料価格",
        "nb": "Drivstoffpris",
        "th": "ราคาน้ำมัน"
    },
    "Full Cycles (EFC)": {
        "en": "Full Cycles (EFC)",
        "de": "Vollzyklen (EFC)",
        "fr": "Cycles complets (EFC)",
        "es": "Ciclos completos (EFC)",
        "zh-Hans": "等效全充放电循环 (EFC)",
        "ja": "等価フル充電サイクル (EFC)",
        "nb": "Fulle sykluser (EFC)",
        "th": "รอบการชาร์จเต็ม (EFC)"
    },
    "Full-Size SUV / Truck": {
        "en": "Full-Size SUV / Truck",
        "de": "Full-Size SUV / Pickup",
        "fr": "Grand SUV / Pick-up",
        "es": "SUV grande / Camioneta",
        "zh-Hans": "大型 SUV / 皮卡",
        "ja": "フルサイズSUV / ピックアップトラック",
        "nb": "Stor SUV / pickup",
        "th": "รถ SUV ขนาดใหญ่ / กระบะ"
    },
    "Garage": {
        "en": "Garage",
        "de": "Garage",
        "fr": "Garage",
        "es": "Garaje",
        "zh-Hans": "车库",
        "ja": "ガレージ",
        "nb": "Garasje",
        "th": "โรงรถ"
    },
    "Garage Options": {
        "en": "Garage Options",
        "de": "Garage-Optionen",
        "fr": "Options du garage",
        "es": "Opciones del garaje",
        "zh-Hans": "车库选项",
        "ja": "ガレージオプション",
        "nb": "Garasjevalg",
        "th": "ตัวเลือกโรงรถ"
    },
    "Gas Baseline Archetype": {
        "en": "Gas Baseline Archetype",
        "de": "Benzin-Vergleichstyp",
        "fr": "Archétype de référence essence",
        "es": "Arquetipo base de gasolina",
        "zh-Hans": "对照燃油车型",
        "ja": "比較対象ガソリン車タイプ",
        "nb": "Bensin-referansetype",
        "th": "ประเภทรถยนต์น้ำมันอ้างอิง"
    },
    "Gas Engine Baseline (Savings Calculator)": {
        "en": "Gas Engine Baseline (Savings Calculator)",
        "de": "Verbrenner-Basis (Ersparnisrechner)",
        "fr": "Référence moteur thermique (Calculateur d'économies)",
        "es": "Base de motor a gasolina (Calculadora de ahorro)",
        "zh-Hans": "燃油基准参数 (节省计算器)",
        "ja": "ガソリン車基準 (節約額計算)",
        "nb": "Bensinmotor-referanse (Sparekalkulator)",
        "th": "เกณฑ์เปรียบเทียบเครื่องยนต์น้ำมัน (คำนวณเงินที่ประหยัด)"
    },
    "Gas Equivalent": {
        "en": "Gas Equivalent",
        "de": "Benzin-Äquivalent",
        "fr": "Équivalent essence",
        "es": "Equivalente en gasolina",
        "zh-Hans": "等效燃油",
        "ja": "ガソリン換算",
        "nb": "Bensinekvivalent",
        "th": "เทียบเท่าน้ำมัน"
    },
    "Gas Fuel Efficiency": {
        "en": "Gas Fuel Efficiency",
        "de": "Kraftstoffverbrauch",
        "fr": "Consommation d'essence",
        "es": "Rendimiento de gasolina",
        "zh-Hans": "燃油消耗率",
        "ja": "ガソリン燃費",
        "nb": "Drivstoffeffektivitet",
        "th": "อัตราสิ้นเปลืองน้ำมัน"
    },
    "Gas Savings Comparison": {
        "en": "Gas Savings Comparison",
        "de": "Benzinersparnis-Vergleich",
        "fr": "Comparaison des économies vs essence",
        "es": "Comparación de ahorro en gasolina",
        "zh-Hans": "燃油花费节省对比",
        "ja": "ガソリン節約額の比較",
        "nb": "Sammenligning av bensinbesparelse",
        "th": "เปรียบเทียบการประหยัดค่าน้ำมัน"
    },
    "Generated on %@": {
        "en": "Generated on %1$@",
        "de": "Erstellt am %1$@",
        "fr": "Généré le %1$@",
        "es": "Generado el %1$@",
        "zh-Hans": "生成于 %1$@",
        "ja": "作成日時: %1$@",
        "nb": "Generert %1$@",
        "th": "สร้างเมื่อ %1$@"
    },
    "Google Account": {
        "en": "Google Account",
        "de": "Google-Konto",
        "fr": "Compte Google",
        "es": "Cuenta de Google",
        "zh-Hans": "Google 账号",
        "ja": "Google アカウント",
        "nb": "Google-konto",
        "th": "บัญชี Google"
    },
    "Habit review and longevity impact for %@": {
        "en": "Habit review and longevity impact for %1$@",
        "de": "Gewohnheitsanalyse und Einfluss auf Langlebigkeit für %1$@",
        "fr": "Bilan des habitudes et impact sur la longévité pour %1$@",
        "es": "Revisión de hábitos e impacto en longevidad para %1$@",
        "zh-Hans": "%1$@ 的充电习惯评估与电池寿命影响",
        "ja": "%1$@ の充電習慣レビューとバッテリー寿命への影響",
        "nb": "Vanevurdering og levetidseffekt for %1$@",
        "th": "การทบทวนพฤติกรรมและผลกระทบต่ออายุการใช้งานสำหรับ %1$@"
    },
    "History": {
        "en": "History",
        "de": "Verlauf",
        "fr": "Historique",
        "es": "Historial",
        "zh-Hans": "历史记录",
        "ja": "履歴",
        "nb": "Historikk",
        "th": "ประวัติ"
    },
    "Home": {
        "en": "Home",
        "de": "Zuhause",
        "fr": "Domicile",
        "es": "Casa",
        "zh-Hans": "家",
        "ja": "自宅",
        "nb": "Hjem",
        "th": "บ้าน"
    },
    "Home Charging & Tariff": {
        "en": "Home Charging & Tariff",
        "de": "Heimladen & Tarif",
        "fr": "Recharge à domicile et tarif",
        "es": "Carga en casa y tarifa",
        "zh-Hans": "家庭充电与电价",
        "ja": "自宅充電と電気料金",
        "nb": "Hjemmelading og tariff",
        "th": "การชาร์จที่บ้านและค่าไฟ"
    },
    "Home Tariff Plan": {
        "en": "Home Tariff Plan",
        "de": "Haushaltstarif",
        "fr": "Plan tarifaire résidentiel",
        "es": "Plan tarifario residencial",
        "zh-Hans": "家用电价方案",
        "ja": "自宅の電気料金プラン",
        "nb": "Hjemmetariffplan",
        "th": "แผนอัตราค่าไฟบ้าน"
    },
    "Home Wall Charger Power": {
        "en": "Home Wall Charger Power",
        "de": "Wallbox-Ladeleistung",
        "fr": "Puissance de la borne de recharge",
        "es": "Potencia del cargador de pared",
        "zh-Hans": "家用充电桩功率",
        "ja": "自宅ウォールチャージャー出力",
        "nb": "Effekt på hjemmelader",
        "th": "กำลังไฟเครื่องชาร์จบ้าน"
    },
    "Home sessions default to AC charging with the cost deferred to your electric bill.": {
        "en": "Home sessions default to AC charging with the cost deferred to your electric bill.",
        "de": "Heimladungen verwenden standardmäßig AC-Laden und werden über Ihre Stromrechnung abgerechnet.",
        "fr": "Les sessions à domicile utilisent la charge AC par défaut et sont reportées sur votre facture d'électricité.",
        "es": "Las sesiones en casa son por defecto en CA y el costo se refleja en su factura de luz.",
        "zh-Hans": "家庭充电默认采用交流慢充，费用将计入您的家庭电费账单。",
        "ja": "自宅セッションはデフォルトで普通充電 (AC) となり、電気料金請求に計上されます。",
        "nb": "Hjemmelading settes som standard til AC-lading med kostnaden på strømregningen din.",
        "th": "การชาร์จที่บ้านจะตั้งต้นเป็นแบบ AC และคำนวณค่าไฟรวมในบิลบ้านของคุณ"
    },
    "ICE Vehicle Category": {
        "en": "ICE Vehicle Category",
        "de": "Verbrenner-Fahrzeugklasse",
        "fr": "Catégorie de véhicule thermique",
        "es": "Categoría de vehículo de combustión",
        "zh-Hans": "燃油车型类别",
        "ja": "ガソリン車カテゴリー",
        "nb": "Fossilbilkategori",
        "th": "หมวดหมู่รถยนต์เครื่องยนต์สันดาป"
    },
    "Import CSV…": {
        "en": "Import CSV…",
        "de": "CSV importieren…",
        "fr": "Importer un CSV…",
        "es": "Importar CSV…",
        "zh-Hans": "导入 CSV…",
        "ja": "CSV をインポート…",
        "nb": "Importer CSV…",
        "th": "นำเข้า CSV…"
    },
    "Import/Export": {
        "en": "Import/Export",
        "de": "Import/Export",
        "fr": "Importer/Exporter",
        "es": "Importar/Exportar",
        "zh-Hans": "导入 / 导出",
        "ja": "インポート/エクスポート",
        "nb": "Import/Eksport",
        "th": "นำเข้า/ส่งออก"
    },
    "Insufficient Data for Battery Health": {
        "comment": "A title displayed when there is not enough data to show battery health.",
        "en": "Insufficient Data for Battery Health",
        "de": "Unzureichende Daten für Batteriegesundheit",
        "fr": "Données insuffisantes pour la santé de la batterie",
        "es": "Datos insuficientes para la salud de la batería",
        "zh-Hans": "电池健康分析数据不足",
        "ja": "バッテリー健全度分析のデータが不足しています",
        "nb": "Utilstrekkelig data for batterihelse",
        "th": "ข้อมูลไม่เพียงพอสำหรับวิเคราะห์สุขภาพแบตเตอรี่"
    },
    "Invalid SoC range": {
        "en": "Invalid SoC range",
        "de": "Ungültiger SoC-Bereich",
        "fr": "Plage de SoC invalide",
        "es": "Rango de SoC inválido",
        "zh-Hans": "电量百分比区间无效",
        "ja": "無効な SoC 範囲です",
        "nb": "Ugyldig SoC-intervall",
        "th": "ช่วงระดับแบตเตอรี่ (SoC) ไม่ถูกต้อง"
    },
    "JOULE BATTERY HEALTH CERTIFICATE": {
        "en": "JOULE BATTERY HEALTH CERTIFICATE",
        "de": "JOULE BATTERIEGESUNDHEITS-ZERTIFIKAT",
        "fr": "CERTIFICAT DE SANTÉ DE BATTERIE JOULE",
        "es": "CERTIFICADO DE SALUD DE BATERÍA JOULE",
        "zh-Hans": "JOULE 电池健康认证证书",
        "ja": "JOULE バッテリー健全度証明書",
        "nb": "JOULE BATTERIHELSECERTIFIKAT",
        "th": "ใบรับรองสุขภาพแบตเตอรี่ JOULE"
    },
    "Joule": {
        "en": "Joule",
        "de": "Joule",
        "fr": "Joule",
        "es": "Joule",
        "zh-Hans": "Joule",
        "ja": "Joule",
        "nb": "Joule",
        "th": "Joule"
    },
    "Joule EV Battery Analytics": {
        "en": "Joule EV Battery Analytics",
        "de": "Joule EV Batterie-Analytik",
        "fr": "Analytique de batterie VE Joule",
        "es": "Analítica de batería para VE Joule",
        "zh-Hans": "Joule 电动车电池分析",
        "ja": "Joule EV バッテリー分析",
        "nb": "Joule Elbil-batterianalyse",
        "th": "การวิเคราะห์แบตเตอรี่ EV Joule"
    },
    "Joule.": {
        "comment": "The name of the app.",
        "en": "Joule.",
        "de": "Joule.",
        "fr": "Joule.",
        "es": "Joule.",
        "zh-Hans": "Joule.",
        "ja": "Joule.",
        "nb": "Joule.",
        "th": "Joule."
    },
    "Joule always uses the dark appearance, even when your device is in Light Mode.": {
        "en": "Joule always uses the dark appearance, even when your device is in Light Mode.",
        "de": "Joule verwendet immer das dunkle Erscheinungsbild, auch wenn Ihr Gerät im Hell-Modus ist.",
        "fr": "Joule utilise toujours le thème sombre, même lorsque votre appareil est en mode clair.",
        "es": "Joule siempre utiliza el modo oscuro, incluso si tu dispositivo está en modo claro.",
        "zh-Hans": "即使您的设备处于浅色模式，Joule 也将始终保持深色外观。",
        "ja": "デバイスがライトモードの場合でも、Joule は常にダークモードで表示されます。",
        "nb": "Joule bruker alltid mørkt utseende, selv når enheten din er i lyst modus.",
        "th": "Joule จะใช้ธีมมืดเสมอ แม้ว่าอุปกรณ์ของคุณจะตั้งค่าเป็นโหมดสว่าง"
    },
    "Joule always uses the light appearance, even when your device is in Dark Mode.": {
        "en": "Joule always uses the light appearance, even when your device is in Dark Mode.",
        "de": "Joule verwendet immer das helle Erscheinungsbild, auch wenn Ihr Gerät im Dunkel-Modus ist.",
        "fr": "Joule utilise toujours le thème clair, même lorsque votre appareil est en mode sombre.",
        "es": "Joule siempre utiliza el modo claro, incluso si tu dispositivo está en modo oscuro.",
        "zh-Hans": "即使您的设备处于深色模式，Joule 也将始终保持浅色外观。",
        "ja": "デバイスがダークモードの場合でも、Joule は常にライトモードで表示されます。",
        "nb": "Joule bruker alltid lyst utseende, selv når enheten din er i mørkt modus.",
        "th": "Joule จะใช้ธีมสว่างเสมอ แม้ว่าอุปกรณ์ของคุณจะตั้งค่าเป็นโหมดมืด"
    },
    "Joule follows your device's Light/Dark appearance setting.": {
        "en": "Joule follows your device's Light/Dark appearance setting.",
        "de": "Joule folgt der Hell-/Dunkel-Einstellung Ihres Geräts.",
        "fr": "Joule s'adapte automatiquement au réglage Clair/Sombre de votre appareil.",
        "es": "Joule sigue la configuración Claro/Oscuro de tu dispositivo.",
        "zh-Hans": "Joule 将自动跟随您设备的浅色/深色外观设置。",
        "ja": "Joule はデバイスのライト/ダーク外観設定に従います。",
        "nb": "Joule følger enhetens innstilling for lyst/mørkt utseende.",
        "th": "Joule จะปรับตามการตั้งค่าธีม สว่าง/มืด ของอุปกรณ์ของคุณ"
    },
    "kW": {
        "en": "kW",
        "de": "kW",
        "fr": "kW",
        "es": "kW",
        "zh-Hans": "kW",
        "ja": "kW",
        "nb": "kW",
        "th": "kW"
    },
    "kWh": {
        "en": "kWh",
        "de": "kWh",
        "fr": "kWh",
        "es": "kWh",
        "zh-Hans": "kWh",
        "ja": "kWh",
        "nb": "kWh",
        "th": "kWh"
    },
    "License Plate": {
        "en": "License Plate",
        "de": "Kennzeichen",
        "fr": "Plaque d'immatriculation",
        "es": "Matrícula / Placa",
        "zh-Hans": "车牌号",
        "ja": "ナンバープレート",
        "nb": "Registreringsnummer",
        "th": "ทะเบียนรถ"
    },
    "Lifetime Totals": {
        "en": "Lifetime Totals",
        "de": "Gesamtsumme",
        "fr": "Totaux cumulés",
        "es": "Totales acumulados",
        "zh-Hans": "累计总计",
        "ja": "累計合計",
        "nb": "Totaler levetid",
        "th": "ยอดรวมทั้งหมด"
    },
    "Light": {
        "en": "Light",
        "de": "Hell",
        "fr": "Clair",
        "es": "Claro",
        "zh-Hans": "浅色",
        "ja": "ライト",
        "nb": "Lyst",
        "th": "สว่าง"
    },
    "Local Mode (Offline-First)": {
        "en": "Local Mode (Offline-First)",
        "de": "Lokaler Modus (Offline zuerst)",
        "fr": "Mode local (hors-ligne)",
        "es": "Modo local (Primero desconectado)",
        "zh-Hans": "本地模式 (离线优先)",
        "ja": "ローカルモード (オフライン優先)",
        "nb": "Lokal modus (Frakoblet først)",
        "th": "โหมดออฟไลน์ (บันทึกในเครื่อง)"
    },
    "Local Sessions": {
        "en": "Local Sessions",
        "de": "Lokale Ladevorgänge",
        "fr": "Sessions locales",
        "es": "Sesiones locales",
        "zh-Hans": "本地记录",
        "ja": "ローカルのセッション",
        "nb": "Lokale økter",
        "th": "รายการในเครื่อง"
    },
    "Location": {
        "en": "Location",
        "de": "Standort",
        "fr": "Emplacement",
        "es": "Ubicación",
        "zh-Hans": "充电地点",
        "ja": "場所",
        "nb": "Plassering",
        "th": "สถานที่"
    },
    "Location Name": {
        "en": "Location Name",
        "de": "Standortname",
        "fr": "Nom du lieu",
        "es": "Nombre de ubicación",
        "zh-Hans": "地点名称",
        "ja": "場所の名前",
        "nb": "Plasseringsnavn",
        "th": "ชื่อสถานที่"
    },
    "Location Type": {
        "en": "Location Type",
        "de": "Standorttyp",
        "fr": "Type de lieu",
        "es": "Tipo de ubicación",
        "zh-Hans": "地点类型",
        "ja": "充電場所のタイプ",
        "nb": "Plasseringstype",
        "th": "ประเภทสถานที่"
    },
    "Log Charge": {
        "comment": "A button to log a new charging session.",
        "en": "Log Charge",
        "de": "Ladevorgang erfassen",
        "fr": "Enregistrer la recharge",
        "es": "Registrar carga",
        "zh-Hans": "记录充电",
        "ja": "充電を記録",
        "nb": "Loggfør lading",
        "th": "บันทึกการชาร์จ"
    },
    "Log a charge with start and end battery % on your iPhone to estimate State of Health.": {
        "en": "Log a charge with start and end battery % on your iPhone to estimate State of Health.",
        "de": "Erfassen Sie eine Ladung mit Start- und End-Batteriestand % auf dem iPhone, um die Batteriegesundheit zu schätzen.",
        "fr": "Enregistrez une recharge avec les % de batterie de début et fin sur votre iPhone pour évaluer l'état de santé.",
        "es": "Registra una carga con % inicial y final de batería en tu iPhone para estimar la salud de la batería.",
        "zh-Hans": "在 iPhone 上记录包含起始和结束电量百分比的充电，以评估电池健康状态。",
        "ja": "バッテリー健全度を推定するため、iPhone で開始・終了％を含む充電を記録してください。",
        "nb": "Logg en lading med start- og sluttbatteri-% på din iPhone for å estimere batterihelsen.",
        "th": "บันทึกการชาร์จพร้อม % แบตเตอรี่เริ่มต้นและสิ้นสุดบน iPhone ของคุณเพื่อประเมินสุขภาพแบตเตอรี่"
    },
    "Log a charge with start and end battery % to estimate State of Health.": {
        "en": "Log a charge with start and end battery % to estimate State of Health.",
        "de": "Erfassen Sie eine Ladung mit Start- und End-Batteriestand %, um die Batteriegesundheit zu schätzen.",
        "fr": "Enregistrez une recharge avec les % de batterie de début et fin pour estimer la santé de la batterie.",
        "es": "Registra una carga con % inicial y final de batería para estimar la salud de la batería.",
        "zh-Hans": "记录包含起始和结束电量百分比的充电，以估算电池健康状态。",
        "ja": "バッテリー健全度を推定するため、開始・終了％を含む充電を記録してください。",
        "nb": "Logg en lading med start- og sluttbatteri-% for å estimere batterihelse.",
        "th": "บันทึกการชาร์จพร้อม % แบตเตอรี่เริ่มต้นและสิ้นสุดเพื่อประเมินสุขภาพแบตเตอรี่"
    },
    "Log charging sessions with both Start SoC and End SoC to enable capacity estimation and degradation tracking.": {
        "comment": "A description of the benefits of logging charging sessions.",
        "en": "Log charging sessions with both Start SoC and End SoC to enable capacity estimation and degradation tracking.",
        "de": "Erfassen Sie Ladevorgänge mit Start- und End-SoC, um Kapazitätsschätzung und Degradationsverfolgung zu aktivieren.",
        "fr": "Enregistrez des sessions avec le SoC de début et de fin pour activer l'estimation de capacité et le suivi de dégradation.",
        "es": "Registra sesiones con SoC inicial y final para habilitar la estimación de capacidad y el seguimiento de degradación.",
        "zh-Hans": "记录包含起始与结束 SoC (电量) 的充电记录，以启用容量估算和衰减追踪。",
        "ja": "容量推定と劣化追跡を有効にするため、開始 SoC と終了 SoC の両方を入力して充電を記録してください。",
        "nb": "Loggfør ladeøkter med både start- og slutt-SoC for å aktivere kapasitetsberegning og degraderingssporing.",
        "th": "บันทึกการชาร์จโดยระบุระดับแบตเตอรี่ทั้งก่อนและหลังชาร์จ (SoC) เพื่อเปิดใช้งานการประเมินความจุและติดตามการเสื่อมสภาพ"
    },
    "Log mileage on at least two charging sessions to view your driving efficiency trends over time.": {
        "comment": "A description of the benefits of logging mileage.",
        "en": "Log mileage on at least two charging sessions to view your driving efficiency trends over time.",
        "de": "Erfassen Sie den Kilometerstand bei mindestens zwei Ladevorgängen, um Ihre Verbrauchstrends im Zeitverlauf zu sehen.",
        "fr": "Renseignez le kilométrage sur au moins deux sessions pour voir vos tendances d'efficacité au fil du temps.",
        "es": "Registra el kilometraje en al menos dos sesiones para ver las tendencias de eficiencia de conducción a lo largo del tiempo.",
        "zh-Hans": "在至少两次充电记录中填写行驶里程，即可查看长期的行车能效趋势。",
        "ja": "2回以上の充電セッションで走行距離を記録すると、電費効率の推移を確認できます。",
        "nb": "Loggfør kilometerstand på minst to ladeøkter for å se kjøreeffektivitetstrender over tid.",
        "th": "ระบุเลขไมล์ในการชาร์จอย่างน้อย 2 ครั้งขึ้นไป เพื่อดูแนวโน้มประสิทธิภาพการขับขี่ตามช่วงเวลา"
    },
    "Log start and end charge %": {
        "en": "Log start and end charge %",
        "de": "Start- und End-Ladestand in % erfassen",
        "fr": "Enregistrer le % de charge de début et de fin",
        "es": "Registra el % de carga inicial y final",
        "zh-Hans": "记录起始和结束充电电量 %",
        "ja": "開始と終了の充電 ％ を記録",
        "nb": "Loggfør start- og sluttlade-%",
        "th": "บันทึก % แบตเตอรี่ก่อนและหลังชาร์จ"
    },
    "Log your first charging session or import a CSV file to view your analytics.": {
        "comment": "A description of the content of the \"No Charging Data\" view.",
        "en": "Log your first charging session or import a CSV file to view your analytics.",
        "de": "Erfassen Sie Ihren ersten Ladevorgang oder importieren Sie eine CSV-Datei, um Ihre Statistiken anzuzeigen.",
        "fr": "Enregistrez votre première session de recharge ou importez un fichier CSV pour voir vos analyses.",
        "es": "Registra tu primera sesión de carga o importa un archivo CSV para ver tus estadísticas.",
        "zh-Hans": "记录您的第一次充电或导入 CSV 文件以查看数据分析。",
        "ja": "最初の充電セッションを記録するか、CSV ファイルをインポートして分析を表示します。",
        "nb": "Loggfør din første ladeøkt eller importer en CSV-fil for å se analysene dine.",
        "th": "บันทึกการชาร์จครั้งแรกของคุณ หรือนำเข้าไฟล์ CSV เพื่อดูการวิเคราะห์ข้อมูล"
    },
    "Logged at no cost. The energy still counts toward your stats and gas savings.": {
        "en": "Logged at no cost. The energy still counts toward your stats and gas savings.",
        "de": "Kostenlos erfasst. Die Energie wird dennoch für Statistiken und Benzinersparnis gezählt.",
        "fr": "Enregistré sans frais. L'énergie est toujours comptabilisée dans vos statistiques et économies.",
        "es": "Registrado sin costo. La energía aún se cuenta para tus estadísticas y ahorros.",
        "zh-Hans": "免费记录。电量仍会计入您的统计数据和燃油节省计算中。",
        "ja": "費用ゼロで記録されました。電力量は統計およびガソリン節約額に加算されます。",
        "nb": "Loggført uten kostnad. Energien teller fortsatt med i statistikk og bensinbesparelser.",
        "th": "บันทึกแบบไม่มีค่าใช้จ่าย พลังงานยังคงถูกนำไปคำนวณในสถิติและการประหยัดค่าน้ำมัน"
    },
    "Make Active": {
        "en": "Make Active",
        "de": "Als aktiv setzen",
        "fr": "Définir comme actif",
        "es": "Establecer como activo",
        "zh-Hans": "设为当前车辆",
        "ja": "使用中に設定",
        "nb": "Gjør aktiv",
        "th": "ตั้งเป็นรถที่ใช้งาน"
    },
    "Manage Garage (%@)": {
        "en": "Manage Garage (%1$@)",
        "de": "Garage verwalten (%1$@)",
        "fr": "Gérer le garage (%1$@)",
        "es": "Administrar garaje (%1$@)",
        "zh-Hans": "管理车库 (%1$@)",
        "ja": "ガレージを管理 (%1$@)",
        "nb": "Administrer garasje (%1$@)",
        "th": "จัดการโรงรถ (%1$@)"
    },
    "Manage Garage (%@)…": {
        "en": "Manage Garage (%1$@)…",
        "de": "Garage verwalten (%1$@)…",
        "fr": "Gérer le garage (%1$@)…",
        "es": "Administrar garaje (%1$@)…",
        "zh-Hans": "管理车库 (%1$@)…",
        "ja": "ガレージを管理 (%1$@)…",
        "nb": "Administrer garasje (%1$@)…",
        "th": "จัดการโรงรถ (%1$@)…"
    },
    "Manage multiple EV profiles with custom battery chemistries, tariffs, and gas baselines.": {
        "en": "Manage multiple EV profiles with custom battery chemistries, tariffs, and gas baselines.",
        "de": "Verwalten Sie mehrere Elektrofahrzeug-Profile mit individueller Batteriechemie, Tarifen und Benzin-Referenzen.",
        "fr": "Gérez plusieurs profils de VE avec chimies de batterie, tarifs et références d'essence personnalisés.",
        "es": "Administra múltiples perfiles de VE con químicas de batería, tarifas y líneas base de gasolina personalizadas.",
        "zh-Hans": "管理多辆电动车档案，支持自定义电池化学成分、家庭电价和燃油对比基准。",
        "ja": "バッテリー種類、電気料金、ガソリン基準を車両ごとにカスタマイズして複数EVを一元管理できます。",
        "nb": "Administrer flere elbilprofiler med tilpasset batterikjemi, tariffer og bensinreferanser.",
        "th": "จัดการโปรไฟล์รถยนต์ไฟฟ้าหลายคัน พร้อมปรับแต่งเคมีแบตเตอรี่ อัตราค่าไฟ และเกณฑ์เปรียบเทียบน้ำมัน"
    },
    "Merge data into canonical records and remove duplicates.": {
        "en": "Merge data into canonical records and remove duplicates.",
        "de": "Daten zu eindeutigen Einträgen zusammenführen und Duplikate entfernen.",
        "fr": "Fusionner les données en enregistrements principaux et supprimer les doublons.",
        "es": "Fusionar datos en registros principales y eliminar duplicados.",
        "zh-Hans": "将数据合并为标准记录并移除重复项。",
        "ja": "データを統合して重複レコードを削除します。",
        "nb": "Slå sammen data til standardposter og fjern duplikater.",
        "th": "ผสานข้อมูลเข้าด้วยกันและลบรายการที่ซ้ำซ้อน"
    },
    "Mid-Size SUV / Crossover": {
        "en": "Mid-Size SUV / Crossover",
        "de": "Mittelklasse-SUV / Crossover",
        "fr": "SUV intermédiaire / Crossover",
        "es": "SUV mediano / Crossover",
        "zh-Hans": "中型 SUV / 跨界车",
        "ja": "ミドルサイズSUV / クロスオーバー",
        "nb": "Mellomstor SUV / Crossover",
        "th": "SUV ขนาดกลาง / ครอสโอเวอร์"
    },
    "Mileage": {
        "en": "Mileage",
        "de": "Kilometerstand",
        "fr": "Kilométrage",
        "es": "Kilometraje",
        "zh-Hans": "里程",
        "ja": "走行距離",
        "nb": "Kilometerstand",
        "th": "ระยะทางสะสม"
    },
    "min": {
        "en": "min",
        "de": "Min.",
        "fr": "min",
        "es": "min",
        "zh-Hans": "分钟",
        "ja": "分",
        "nb": "min",
        "th": "นาที"
    },
    "Mode": {
        "en": "Mode",
        "de": "Modus",
        "fr": "Mode",
        "es": "Modo",
        "zh-Hans": "模式",
        "ja": "モード",
        "nb": "Modus",
        "th": "โหมด"
    },
    "Monthly Stats": {
        "en": "Monthly Stats",
        "de": "Monatsstatistik",
        "fr": "Statistiques mensuelles",
        "es": "Estadísticas mensuales",
        "zh-Hans": "月度统计",
        "ja": "月間統計",
        "nb": "Månedlig statistikk",
        "th": "สถิติรายเดือน"
    },
    "Multi-Vehicle Garage": {
        "en": "Multi-Vehicle Garage",
        "de": "Fahrzeug-Garage",
        "fr": "Garage multi-véhicules",
        "es": "Garaje multivehículo",
        "zh-Hans": "多车辆车库",
        "ja": "複数台ガレージ",
        "nb": "Flerbilsgarasje",
        "th": "โรงรถสำหรับรถหลายคัน"
    },
    "New Session": {
        "en": "New Session",
        "de": "Neuer Ladevorgang",
        "fr": "Nouvelle session",
        "es": "Nueva sesión",
        "zh-Hans": "新建记录",
        "ja": "新規セッション",
        "nb": "Ny ladeøkt",
        "th": "บันทึกการชาร์จใหม่"
    },
    "No Data Yet": {
        "en": "No Data Yet",
        "de": "Noch keine Daten",
        "fr": "Pas encore de données",
        "es": "Aún no hay datos",
        "zh-Hans": "暂无数据",
        "ja": "データがありません",
        "nb": "Ingen data ennå",
        "th": "ยังไม่มีข้อมูล"
    },
    "No Driving Efficiency Data": {
        "comment": "A message displayed when the user has not logged any driving efficiency data.",
        "en": "No Driving Efficiency Data",
        "de": "Keine Fahrleistungsdaten",
        "fr": "Aucune donnée d'efficacité de conduite",
        "es": "Sin datos de eficiencia de conducción",
        "zh-Hans": "暂无能效数据",
        "ja": "電費効率データがありません",
        "nb": "Ingen kjøreeffektivitetsdata",
        "th": "ไม่มีข้อมูลประสิทธิภาพการขับขี่"
    },
    "No Duplicates Found": {
        "en": "No Duplicates Found",
        "de": "Keine Duplikate gefunden",
        "fr": "Aucun doublon trouvé",
        "es": "No se encontraron duplicados",
        "zh-Hans": "未发现重复记录",
        "ja": "重複は見つかりませんでした",
        "nb": "Ingen duplikater funnet",
        "th": "ไม่พบรายการซ้ำ"
    },
    "No charging history yet.": {
        "comment": "A message displayed when a user has not yet added any charging sessions.",
        "en": "No charging history yet.",
        "de": "Noch keine Ladehistorie vorhanden.",
        "fr": "Aucun historique de recharge pour le moment.",
        "es": "Aún no hay historial de carga.",
        "zh-Hans": "暂无充电历史记录。",
        "ja": "充電履歴がまだありません。",
        "nb": "Ingen ladehistorikk ennå.",
        "th": "ยังไม่มีประวัติการชาร์จ"
    },
    "No charging sessions logged yet.": {
        "en": "No charging sessions logged yet.",
        "de": "Noch keine Ladevorgänge erfasst.",
        "fr": "Aucune session de recharge enregistrée.",
        "es": "Aún no hay sesiones de carga registradas.",
        "zh-Hans": "尚未记录任何充电会话。",
        "ja": "記録された充電セッションはまだありません。",
        "nb": "Ingen ladeøkter loggført ennå.",
        "th": "ยังไม่มีการบันทึกการชาร์จ"
    },
    "Nominal Pack Capacity": {
        "en": "Nominal Pack Capacity",
        "de": "Batterie-Nennkapazität",
        "fr": "Capacité nominale du pack",
        "es": "Capacidad nominal de batería",
        "zh-Hans": "电池标称总容量",
        "ja": "公称バッテリー総容量",
        "nb": "Nominell batterikapasitet",
        "th": "ความจุมาตรฐานของแบตเตอรี่"
    },
    "Nominal: %@ kWh": {
        "en": "Nominal: %1$@ kWh",
        "de": "Nennwert: %1$@ kWh",
        "fr": "Nominale : %1$@ kWh",
        "es": "Nominal: %1$@ kWh",
        "zh-Hans": "标称：%1$@ kWh",
        "ja": "公称: %1$@ kWh",
        "nb": "Nominell: %1$@ kWh",
        "th": "ความจุมาตรฐาน: %1$@ kWh"
    },
    "Notes": {
        "en": "Notes",
        "de": "Notizen",
        "fr": "Notes",
        "es": "Notas",
        "zh-Hans": "备注",
        "ja": "メモ",
        "nb": "Notater",
        "th": "บันทึกเพิ่มเติม"
    },
    "OK": {
        "en": "OK",
        "de": "OK",
        "fr": "OK",
        "es": "Aceptar",
        "zh-Hans": "确定",
        "ja": "OK",
        "nb": "OK",
        "th": "ตกลง"
    },
    "Off-Peak Smart Charging": {
        "comment": "A label displayed above the savings of off-peak smart charging.",
        "en": "Off-Peak Smart Charging",
        "de": "Intelligentes Laden in Nebenzeiten",
        "fr": "Recharge intelligente heures creuses",
        "es": "Carga inteligente en horas valle",
        "zh-Hans": "低谷电价智能充电",
        "ja": "オフピーク スマート充電",
        "nb": "Smartlading utenom topptid",
        "th": "การชาร์จอัจฉริยะช่วง Off-Peak"
    },
    "Offline": {
        "en": "Offline",
        "de": "Offline",
        "fr": "Hors ligne",
        "es": "Sin conexión",
        "zh-Hans": "离线",
        "ja": "オフライン",
        "nb": "Frakoblet",
        "th": "ออฟไลน์"
    },
    "Open the app to start tracking your charging.": {
        "en": "Open the app to start tracking your charging.",
        "de": "Öffnen Sie die App, um Ihre Ladevorgänge zu erfassen.",
        "fr": "Ouvrez l'application pour commencer le suivi de vos recharges.",
        "es": "Abre la aplicación para comenzar a registrar tus cargas.",
        "zh-Hans": "打开 App 开始追踪您的充电数据。",
        "ja": "アプリを開いて充電の追跡を開始してください。",
        "nb": "Åpne appen for å spore ladingen din.",
        "th": "เปิดแอปเพื่อเริ่มติดตามการชาร์จของคุณ"
    },
    "Open to start tracking": {
        "en": "Open to start tracking",
        "de": "Öffnen zum Erfassen",
        "fr": "Ouvrir pour commencer",
        "es": "Abrir para iniciar",
        "zh-Hans": "打开以开始记录",
        "ja": "タップして追跡を開始",
        "nb": "Åpne for å starte sporing",
        "th": "เปิดเพื่อเริ่มบันทึก"
    },
    "Over Time": {
        "en": "Over Time",
        "de": "Im Zeitverlauf",
        "fr": "Au fil du temps",
        "es": "A lo largo del tiempo",
        "zh-Hans": "时间走势",
        "ja": "時系列",
        "nb": "Over tid",
        "th": "ตามเวลา"
    },
    "Overtime Fee": {
        "en": "Overtime Fee",
        "de": "Blockiergebühr",
        "fr": "Frais d'occupation",
        "es": "Tarifa por tiempo extra",
        "zh-Hans": "超时占位费",
        "ja": "超過駐車料金",
        "nb": "Overtidsgebyr",
        "th": "ค่าปรับจอดเกินเวลา"
    },
    "Overview": {
        "en": "Overview",
        "de": "Übersicht",
        "fr": "Aperçu",
        "es": "Resumen",
        "zh-Hans": "概览",
        "ja": "概要",
        "nb": "Oversikt",
        "th": "ภาพรวม"
    },
    "Payment Status": {
        "en": "Payment Status",
        "de": "Zahlungsstatus",
        "fr": "Statut du paiement",
        "es": "Estado del pago",
        "zh-Hans": "支付状态",
        "ja": "支払状況",
        "nb": "Betalingsstatus",
        "th": "สถานะการชำระเงิน"
    },
    "Per %@": {
        "en": "Per %1$@",
        "de": "Pro %1$@",
        "fr": "Par %1$@",
        "es": "Por %1$@",
        "zh-Hans": "每 %1$@",
        "ja": "%1$@ あたり",
        "nb": "Per %1$@",
        "th": "ต่อ %1$@"
    },
    "Pick Another Photo": {
        "en": "Pick Another Photo",
        "de": "Anderes Foto wählen",
        "fr": "Choisir une autre photo",
        "es": "Elegir otra foto",
        "zh-Hans": "选择其他照片",
        "ja": "別の写真を選択",
        "nb": "Velg et annet bilde",
        "th": "เลือกรูปภาพอื่น"
    },
    "Plate / VIN: %@": {
        "en": "Plate / VIN: %1$@",
        "de": "Kennzeichen / FIN: %1$@",
        "fr": "Plaque / VIN : %1$@",
        "es": "Placa / VIN: %1$@",
        "zh-Hans": "车牌 / 车架号: %1$@",
        "ja": "ナンバー / 車台番号: %1$@",
        "nb": "Reg.nr / VIN: %1$@",
        "th": "ทะเบียน / เลขตัวถัง: %1$@"
    },
    "Plate: %@": {
        "en": "Plate: %1$@",
        "de": "Kennzeichen: %1$@",
        "fr": "Plaque : %1$@",
        "es": "Placa: %1$@",
        "zh-Hans": "车牌: %1$@",
        "ja": "ナンバー: %1$@",
        "nb": "Reg.nr: %1$@",
        "th": "ทะเบียน: %1$@"
    },
    "Primary / Default Vehicle": {
        "en": "Primary / Default Vehicle",
        "de": "Primäres / Standard-Fahrzeug",
        "fr": "Véhicule principal / par défaut",
        "es": "Vehículo principal / predeterminado",
        "zh-Hans": "首选 / 默认车辆",
        "ja": "メイン / デフォルト車両",
        "nb": "Hoved- / Standardkjøretøy",
        "th": "รถยนต์หลัก / ค่าเริ่มต้น"
    },
    "Projected 100% Range": {
        "en": "Projected 100% Range",
        "de": "Hochgerechnete 100 % Reichweite",
        "fr": "Autonomie projetée à 100 %",
        "es": "Autonomía proyectada al 100%",
        "zh-Hans": "满电预估续航",
        "ja": "100% 時の推定航続距離",
        "nb": "Beregnet 100 % rekkevidde",
        "th": "ระยะทางประเมินที่ 100%"
    },
    "Public": {
        "en": "Public",
        "de": "Öffentlich",
        "fr": "Public",
        "es": "Público",
        "zh-Hans": "公共充电桩",
        "ja": "公共充電",
        "nb": "Offentlig",
        "th": "สาธารณะ"
    },
    "Range Standard": {
        "en": "Range Standard",
        "de": "Reichweiten-Standard",
        "fr": "Norme d'autonomie",
        "es": "Estándar de autonomía",
        "zh-Hans": "续航测试标准",
        "ja": "航続距離測定基準",
        "nb": "Rekkeviddestandard",
        "th": "มาตรฐานการทดสอบระยะทาง"
    },
    "Rated Range (%@)": {
        "en": "Rated Range (%1$@)",
        "de": "Nennreichweite (%1$@)",
        "fr": "Autonomie homologuée (%1$@)",
        "es": "Autonomía homologada (%1$@)",
        "zh-Hans": "标称续航 (%1$@)",
        "ja": "公称航続距離 (%1$@)",
        "nb": "Oppgitt rekkevidde (%1$@)",
        "th": "ระยะทางประเมิน (%1$@)"
    },
    "Recent Capacity Calculations": {
        "comment": "A heading for the user's recent battery capacity calculations.",
        "en": "Recent Capacity Calculations",
        "de": "Aktuelle Kapazitätsberechnungen",
        "fr": "Calculs récents de capacité",
        "es": "Cálculos recientes de capacidad",
        "zh-Hans": "近期电池容量计算",
        "ja": "最近のバッテリー容量計算",
        "nb": "Nylige kapasitetsberegninger",
        "th": "การคำนวณความจุแบตเตอรี่ล่าสุด"
    },
    "Recent Charges": {
        "en": "Recent Charges",
        "de": "Letzte Ladevorgänge",
        "fr": "Recharges récentes",
        "es": "Cargas recientes",
        "zh-Hans": "近期充电",
        "ja": "最近の充電",
        "nb": "Nylige ladinger",
        "th": "การชาร์จล่าสุด"
    },
    "Refresh": {
        "en": "Refresh",
        "de": "Aktualisieren",
        "fr": "Actualiser",
        "es": "Actualizar",
        "zh-Hans": "刷新",
        "ja": "更新",
        "nb": "Oppdater",
        "th": "รีเฟรช"
    },
    "Remaining Usable Capacity": {
        "en": "Remaining Usable Capacity",
        "de": "Verbleibende nutzbare Kapazität",
        "fr": "Capacité utilisable restante",
        "es": "Capacidad útil restante",
        "zh-Hans": "剩余可用容量",
        "ja": "残存実効容量",
        "nb": "Gjenværende brukbar kapasitet",
        "th": "ความจุที่ใช้งานได้จริงคงเหลือ"
    },
    "Reset to Defaults": {
        "en": "Reset to Defaults",
        "de": "Auf Standard zurücksetzen",
        "fr": "Rétablir les valeurs par défaut",
        "es": "Restablecer a predeterminados",
        "zh-Hans": "重置为默认值",
        "ja": "デフォルトに戻す",
        "nb": "Tilbakestill til standard",
        "th": "รีเซ็ตเป็นค่าเริ่มต้น"
    },
    "Reset Vehicle Specs to Defaults": {
        "en": "Reset Vehicle Specs to Defaults",
        "de": "Fahrzeugdaten auf Werkseinstellungen zurücksetzen",
        "fr": "Réinitialiser les spécifications du véhicule",
        "es": "Restablecer especificaciones del vehículo",
        "zh-Hans": "重置车辆参数为出厂默认值",
        "ja": "車両スペックをデフォルトにリセット",
        "nb": "Tilbakestill kjøretøyspesifikasjoner til standard",
        "th": "รีเซ็ตข้อมูลจำเพาะรถยนต์เป็นค่าเริ่มต้น"
    },
    "Review & Apply": {
        "comment": "A button label that triggers the application of the scanned charging data to the current session.",
        "en": "Review & Apply",
        "de": "Prüfen & Übernehmen",
        "fr": "Vérifier et appliquer",
        "es": "Revisar y aplicar",
        "zh-Hans": "核对并应用",
        "ja": "確認して適用",
        "nb": "Se over og bruk",
        "th": "ตรวจสอบและนำไปใช้"
    },
    "Save": {
        "en": "Save",
        "de": "Speichern",
        "fr": "Enregistrer",
        "es": "Guardar",
        "zh-Hans": "保存",
        "ja": "保存",
        "nb": "Lagre",
        "th": "บันทึก"
    },
    "Saved vs. Gas": {
        "en": "Saved vs. Gas",
        "de": "Ersparnis vs. Benzin",
        "fr": "Économies vs essence",
        "es": "Ahorro vs. gasolina",
        "zh-Hans": "对比燃油节省",
        "ja": "ガソリン比節約額",
        "nb": "Spart vs. bensin",
        "th": "ประหยัดเทียบน้ำมัน"
    },
    "Saved/%@": {
        "en": "Saved/%1$@",
        "de": "Ersparnis/%1$@",
        "fr": "Économisé/%1$@",
        "es": "Ahorrado/%1$@",
        "zh-Hans": "节省/%1$@",
        "ja": "節約/%1$@",
        "nb": "Spart/%1$@",
        "th": "ประหยัด/%1$@"
    },
    "Scan Charger Screen or Receipt": {
        "comment": "A description of the purpose of the screen.",
        "en": "Scan Charger Screen or Receipt",
        "de": "Ladesäulen-Display oder Beleg scannen",
        "fr": "Scanner l'écran de la borne ou le reçu",
        "es": "Escanear pantalla de cargador o recibo",
        "zh-Hans": "扫描充电桩屏幕或账单收据",
        "ja": "充電器画面または領収書をスキャン",
        "nb": "Skann ladeskjerm eller kvittering",
        "th": "สแกนหน้าจอแท่นชาร์จหรือใบเสร็จ"
    },
    "Select a factory preset or enter a custom name and registration details.": {
        "en": "Select a factory preset or enter a custom name and registration details.",
        "de": "Wählen Sie eine Werksvoreinstellung oder geben Sie eigene Angaben ein.",
        "fr": "Sélectionnez un préréglage d'usine ou saisissez un nom et des détails personnalisés.",
        "es": "Selecciona un preajuste de fábrica o ingresa nombre y detalles personalizados.",
        "zh-Hans": "选择出厂预设车型或输入自定义名称与车辆信息。",
        "ja": "プリセットを選択するか、カスタム名と登録情報を入力してください。",
        "nb": "Velg en fabrikkinnstilling eller angi et eget navn og registreringsdetaljer.",
        "th": "เลือกค่าเริ่มต้นจากโรงงานหรือป้อนชื่อและข้อมูลการจดทะเบียนเอง"
    },
    "Select a photo of your EV charger screen, charging app confirmation, or printed receipt to auto-fill session metrics.": {
        "comment": "A description of how to use the receipt scanner.",
        "en": "Select a photo of your EV charger screen, charging app confirmation, or printed receipt to auto-fill session metrics.",
        "de": "Wählen Sie ein Foto Ihres Ladesäulen-Bildschirms, der Lade-App oder eines Belegs, um Daten automatisch auszufüllen.",
        "fr": "Sélectionnez une photo de l'écran du chargeur, de votre application ou d'un reçu pour remplir automatiquement les données.",
        "es": "Selecciona una foto de la pantalla del cargador, app o recibo impreso para autocompletar la sesión.",
        "zh-Hans": "选择充电桩屏幕、充电应用账单截图或打印收据的照片，以自动提取并填充充电参数。",
        "ja": "充電器の画面、充電アプリの完了画面、またはレシートの写真を選択すると、セッション情報が自動入力されます。",
        "nb": "Velg et bilde av laderskjermen, ladeappen eller kvitteringen for å fylle ut økten automatisk.",
        "th": "เลือกรูปภาพหน้าจอแท่นชาร์จ สลิปจากแอป หรือใบเสร็จ เพื่อกรอกข้อมูลการชาร์จโดยอัตโนมัติ"
    },
    "Select a vehicle to set it as active across your dashboard, charging forms, and battery analytics.": {
        "comment": "A description of the purpose of the section.",
        "en": "Select a vehicle to set it as active across your dashboard, charging forms, and battery analytics.",
        "de": "Wählen Sie ein Fahrzeug aus, um es als aktiv für Dashboard, Ladeformulare und Batterieanalysen festzulegen.",
        "fr": "Sélectionnez un véhicule pour l'activer sur votre tableau de bord, formulaires et analyses.",
        "es": "Selecciona un vehículo para activarlo en tu panel, formularios de carga y análisis.",
        "zh-Hans": "选择一辆车辆，将其设为仪表盘、充电录入和电池分析的当前活跃车辆。",
        "ja": "車両を選択して、ダッシュボード、充電記録、バッテリー分析の対象として設定します。",
        "nb": "Velg et kjøretøy for å sette det som aktivt på tvers av oversikten, ladeskjemaer og batterianalyser.",
        "th": "เลือกรถยนต์เพื่อตั้งเป็นรถที่ใช้งานในหน้าหลัก แบบฟอร์มการชาร์จ และการวิเคราะห์แบตเตอรี่"
    },
    "Select your preferred distance/efficiency units and local currency formatting.": {
        "en": "Select your preferred distance/efficiency units and local currency formatting.",
        "de": "Wählen Sie bevorzugte Einheiten für Distanz/Effizienz und Währungsformatierung.",
        "fr": "Choisissez vos unités de distance/efficacité et le format de devise.",
        "es": "Selecciona tus unidades preferidas de distancia/eficiencia y formato de moneda local.",
        "zh-Hans": "选择您习惯的距离/能耗单位及本地货币格式。",
        "ja": "お好みの距離・電費単位および通貨表示形式を選択してください。",
        "nb": "Velg foretrukne enheter for avstand/effektivitet og lokalt valutaformat.",
        "th": "เลือกหน่วยวัดระยะทาง/ประสิทธิภาพ และรูปแบบสกุลเงินที่คุณต้องการ"
    },
    "Sessions": {
        "en": "Sessions",
        "de": "Ladevorgänge",
        "fr": "Sessions",
        "es": "Sesiones",
        "zh-Hans": "充电次数",
        "ja": "セッション",
        "nb": "Ladeøkter",
        "th": "จำนวนครั้ง"
    },
    "Sessions matching this filter will appear here.": {
        "comment": "A message displayed when there are no sessions matching the current search.",
        "en": "Sessions matching this filter will appear here.",
        "de": "Ladevorgänge, die diesem Filter entsprechen, werden hier angezeigt.",
        "fr": "Les sessions correspondant à ce filtre apparaîtront ici.",
        "es": "Las sesiones que coincidan con este filtro aparecerán aquí.",
        "zh-Hans": "符合此筛选条件的充电记录将显示在此处。",
        "ja": "このフィルターに一致するセッションがここに表示されます。",
        "nb": "Ladeøkter som matcher dette filteret vil vises her.",
        "th": "รายการชาร์จที่ตรงกับตัวกรองนี้จะปรากฏที่นี่"
    },
    "Set as Default": {
        "en": "Set as Default",
        "de": "Als Standard festlegen",
        "fr": "Définir par défaut",
        "es": "Establecer como predeterminado",
        "zh-Hans": "设为默认",
        "ja": "デフォルトに設定",
        "nb": "Sett som standard",
        "th": "ตั้งเป็นค่าเริ่มต้น"
    },
    "Settings": {
        "en": "Settings",
        "de": "Einstellungen",
        "fr": "Réglages",
        "es": "Ajustes",
        "zh-Hans": "设置",
        "ja": "設定",
        "nb": "Innstillinger",
        "th": "การตั้งค่า"
    },
    "Settings…": {
        "en": "Settings…",
        "de": "Einstellungen…",
        "fr": "Réglages…",
        "es": "Ajustes…",
        "zh-Hans": "设置…",
        "ja": "設定…",
        "nb": "Innstillinger…",
        "th": "การตั้งค่า…"
    },
    "Share Certificate": {
        "en": "Share Certificate",
        "de": "Zertifikat teilen",
        "fr": "Partager le certificat",
        "es": "Compartir certificado",
        "zh-Hans": "分享证书",
        "ja": "証明書を共有",
        "nb": "Del sertifikat",
        "th": "แชร์ใบรับรอง"
    },
    "Sign In": {
        "en": "Sign In",
        "de": "Anmelden",
        "fr": "Se connecter",
        "es": "Iniciar sesión",
        "zh-Hans": "登录",
        "ja": "サインイン",
        "nb": "Logg inn",
        "th": "เข้าสู่ระบบ"
    },
    "Sign Out": {
        "en": "Sign Out",
        "de": "Abmelden",
        "fr": "Se déconnecter",
        "es": "Cerrar sesión",
        "zh-Hans": "退出登录",
        "ja": "サインアウト",
        "nb": "Logg ut",
        "th": "ออกจากระบบ"
    },
    "Sign in to keep your charging history private to you and in sync across your iPhone, iPad and Mac.": {
        "comment": "A description of the sign-in process.",
        "en": "Sign in to keep your charging history private to you and in sync across your iPhone, iPad and Mac.",
        "de": "Melden Sie sich an, um Ihren Ladeverlauf privat zu halten und zwischen iPhone, iPad und Mac zu synchronisieren.",
        "fr": "Connectez-vous pour synchroniser votre historique en toute confidentialité sur iPhone, iPad et Mac.",
        "es": "Inicia sesión para mantener tu historial privado y sincronizado en tu iPhone, iPad y Mac.",
        "zh-Hans": "登录后可将充电数据安全保存在云端，并在 iPhone、iPad 和 Mac 之间保持私密同步。",
        "ja": "サインインすると、充電履歴が安全に保護され、iPhone、iPad、Mac 間で同期されます。",
        "nb": "Logg inn for å holde ladehistorikken privat og synkronisert på tvers av iPhone, iPad og Mac.",
        "th": "เข้าสู่ระบบเพื่อเก็บประวัติการชาร์จของคุณอย่างปลอดภัย และซิงค์ข้อมูลระหว่าง iPhone, iPad และ Mac"
    },
    "Sign in with Google to Sync": {
        "en": "Sign in with Google to Sync",
        "de": "Mit Google anmelden zum Synchronisieren",
        "fr": "Se connecter avec Google pour synchroniser",
        "es": "Iniciar sesión con Google para sincronizar",
        "zh-Hans": "使用 Google 登录以同步",
        "ja": "Google でサインインして同期",
        "nb": "Logg inn med Google for å synkronisere",
        "th": "เข้าสู่ระบบด้วย Google เพื่อซิงค์ข้อมูล"
    },
    "SoH": {
        "comment": "Abbreviation for State of Health.",
        "en": "SoH",
        "de": "SoH",
        "fr": "SoH",
        "es": "SoH",
        "zh-Hans": "SoH",
        "ja": "SoH",
        "nb": "SoH",
        "th": "SoH"
    },
    "Speed": {
        "en": "Speed",
        "de": "Geschwindigkeit",
        "fr": "Vitesse",
        "es": "Velocidad",
        "zh-Hans": "充电速度",
        "ja": "充電速度",
        "nb": "Ladehastighet",
        "th": "ความเร็วชาร์จ"
    },
    "Spent in %@": {
        "en": "Spent in %1$@",
        "de": "Ausgaben im %1$@",
        "fr": "Dépensé en %1$@",
        "es": "Gastado en %1$@",
        "zh-Hans": "%1$@ 支出",
        "ja": "%1$@ の支出",
        "nb": "Brukt i %1$@",
        "th": "ค่าใช้จ่ายใน %1$@"
    },
    "Standard AC conversion efficiency (90%) and DC dispenser efficiency (95%).": {
        "en": "Standard AC conversion efficiency (90%) and DC dispenser efficiency (95%).",
        "de": "Standard-AC-Umwandlungseffizienz (90 %) und DC-Ladesäuleneffizienz (95 %).",
        "fr": "Rendement de conversion AC standard (90 %) et distributeur DC (95 %).",
        "es": "Eficiencia estándar de conversión CA (90%) y dispensador CC (95%).",
        "zh-Hans": "标准交流转换效率 (90%) 与直流充电桩效率 (95%)。",
        "ja": "標準 AC 変換効率 (90%) および DC 充電器効率 (95%)。",
        "nb": "Standard AC-omformingseffektivitet (90 %) og DC-ladereffektivitet (95 %).",
        "th": "ประสิทธิภาพการแปลงไฟ AC มาตรฐาน (90%) และประสิทธิภาพตู้ชาร์จ DC (95%)"
    },
    "Start": {
        "en": "Start",
        "de": "Start",
        "fr": "Début",
        "es": "Inicio",
        "zh-Hans": "开始",
        "ja": "開始",
        "nb": "Start",
        "th": "เริ่มต้น"
    },
    "Start Battery %": {
        "en": "Start Battery %",
        "de": "Start-Batteriestand %",
        "fr": "% de batterie initial",
        "es": "% de batería inicial",
        "zh-Hans": "初始电量 %",
        "ja": "開始時バッテリー ％",
        "nb": "Startbatteri %",
        "th": "% แบตเตอรี่เริ่มต้น"
    },
    "Start tracking your charging sessions to unlock real-time monthly costs, gas savings comparison, and battery State of Health (SoH) analytics.": {
        "comment": "A description of the benefits of using the app.",
        "en": "Start tracking your charging sessions to unlock real-time monthly costs, gas savings comparison, and battery State of Health (SoH) analytics.",
        "de": "Starten Sie das Erfassen von Ladevorgängen, um monatliche Kosten, Benzinersparnis und Batteriegesundheitsanalysen freizuschalten.",
        "fr": "Enregistrez vos recharges pour débloquer les coûts mensuels, la comparaison vs essence et l'état de santé (SoH) de la batterie.",
        "es": "Comienza a registrar tus cargas para desbloquear costos mensuales en tiempo real, ahorro vs gasolina y estado de salud (SoH) de la batería.",
        "zh-Hans": "开始记录您的充电记录，以实时了解每月花费、燃油节省对比以及电池健康状态 (SoH) 分析。",
        "ja": "充電セッションの追跡を開始して、月々の充電コスト、ガソリン車との比較、バッテリー健全度 (SoH) 分析を確認しましょう。",
        "nb": "Begynn å spore ladeøktene dine for å se månedlige kostnader, bensinbesparelser og batterihelseanalyser (SoH).",
        "th": "เริ่มบันทึกการชาร์จของคุณเพื่อดูค่าใช้จ่ายรายเดือน การเปรียบเทียบการประหยัดค่าน้ำมัน และการวิเคราะห์สุขภาพแบตเตอรี่ (SoH) แบบเรียลไทม์"
    },
    "Starting below 15% increases anode internal resistance. Aim to plug in around 15%–20% buffer.": {
        "comment": "A warning for starting a session below 15% battery capacity.",
        "en": "Starting below 15% increases anode internal resistance. Aim to plug in around 15%–20% buffer.",
        "de": "Start unter 15 % erhöht den Innenwiderstand der Anode. Empfohlen: Einstecken bei ca. 15 %–20 % Restpuffer.",
        "fr": "Commencer en dessous de 15 % augmente la résistance interne. Visez à brancher vers 15 %–20 %.",
        "es": "Iniciar con menos del 15% aumenta la resistencia interna. Procura conectar alrededor del 15%–20%.",
        "zh-Hans": "电量低于 15% 时开始充电会增加阳极内阻。建议在剩余 15%–20% 电量时连接充电。",
        "ja": "15% 未満からの充電は内部抵抗を高めます。15%〜20% 程度の余裕をもって充電することをおすすめします。",
        "nb": "Lading som starter under 15 % øker indre motstand. Sikt på å koble til rundt 15 %–20 % buffer.",
        "th": "การเริ่มชาร์จเมื่อแบตต่ำกว่า 15% จะเพิ่มความต้านทานภายใน แนะนำให้เริ่มชาร์จที่ระดับ 15%–20%"
    },
    "State of Health": {
        "en": "State of Health",
        "de": "Batteriezustand (SoH)",
        "fr": "État de santé",
        "es": "Estado de salud",
        "zh-Hans": "电池健康状态",
        "ja": "バッテリー健全度",
        "nb": "Batterihelse (SoH)",
        "th": "สุขภาพแบตเตอรี่"
    },
    "Sync Now": {
        "en": "Sync Now",
        "de": "Jetzt synchronisieren",
        "fr": "Synchroniser maintenant",
        "es": "Sincronizar ahora",
        "zh-Hans": "立即同步",
        "ja": "今すぐ同期",
        "nb": "Synkroniser nå",
        "th": "ซิงค์ข้อมูลทันที"
    },
    "Synced Sessions": {
        "en": "Synced Sessions",
        "de": "Synchronisierte Ladevorgänge",
        "fr": "Sessions synchronisées",
        "es": "Sesiones sincronizadas",
        "zh-Hans": "已同步记录",
        "ja": "同期済みセッション",
        "nb": "Synkroniserte økter",
        "th": "รายการที่ซิงค์แล้ว"
    },
    "System": {
        "en": "System",
        "de": "System",
        "fr": "Système",
        "es": "Sistema",
        "zh-Hans": "跟随系统",
        "ja": "システム",
        "nb": "System",
        "th": "ตามระบบ"
    },
    "Tariff Model": {
        "en": "Tariff Model",
        "de": "Tarifmodell",
        "fr": "Modèle tarifaire",
        "es": "Modelo de tarifa",
        "zh-Hans": "电价方案",
        "ja": "料金モデル",
        "nb": "Tariffmodell",
        "th": "รูปแบบอัตราค่าไฟฟ้า"
    },
    "Tariff Rate": {
        "en": "Tariff Rate",
        "de": "Tarifsatz",
        "fr": "Taux tarifaire",
        "es": "Tasa de tarifa",
        "zh-Hans": "电费费率",
        "ja": "電気料金単価",
        "nb": "Tariffsats",
        "th": "เรทค่าไฟ"
    },
    "Technical Details": {
        "en": "Technical Details",
        "de": "Technische Details",
        "fr": "Détails techniques",
        "es": "Detalles técnicos",
        "zh-Hans": "技术规格",
        "ja": "技術的詳細",
        "nb": "Tekniske detaljer",
        "th": "รายละเอียดทางเทคนิค"
    },
    "The default vehicle will be pre-selected when launching Joule and creating new charging sessions.": {
        "en": "The default vehicle will be pre-selected when launching Joule and creating new charging sessions.",
        "de": "Das Standardfahrzeug wird beim Öffnen von Joule und beim Erstellen neuer Ladevorgänge vorausgewählt.",
        "fr": "Le véhicule par défaut sera présélectionné au lancement de Joule et lors de la création d'une session.",
        "es": "El vehículo predeterminado se preseleccionará al abrir Joule y crear nuevas sesiones.",
        "zh-Hans": "打开 Joule 以及创建新充电记录时，将默认预选此车辆。",
        "ja": "Joule の起動時や新しい充電セッションの作成時に、デフォルト車両が自動選択されます。",
        "nb": "Standardkjøretøyet velges automatisk ved oppstart av Joule og oppretting av nye ladeøkter.",
        "th": "รถยนต์ค่าเริ่มต้นจะถูกเลือกให้อัตโนมัติเมื่อเปิดแอป Joule และเมื่อสร้างรายการชาร์จใหม่"
    },
    "Theme": {
        "en": "Theme",
        "de": "Design",
        "fr": "Thème",
        "es": "Tema",
        "zh-Hans": "主题",
        "ja": "テーマ",
        "nb": "Tema",
        "th": "ธีม"
    },
    "This resets battery capacity, range, and cycle benchmarks back to %@ factory defaults.": {
        "en": "This resets battery capacity, range, and cycle benchmarks back to %1$@ factory defaults.",
        "de": "Setzt Batteriekapazität, Reichweite und Zyklen-Benchmarks auf die Werkseinstellungen von %1$@ zurück.",
        "fr": "Rétablit la capacité, l'autonomie et les cycles par défaut selon les spécifications d'usine %1$@.",
        "es": "Esto restablece la capacidad, autonomía y ciclos a los valores de fábrica de %1$@.",
        "zh-Hans": "这会将电池容量、续航与循环基准重置为 %1$@ 的出厂默认值。",
        "ja": "バッテリー容量、航続距離、サイクル基準値を %1$@ の工場出荷時デフォルトに戻します。",
        "nb": "Dette tilbakestiller batterikapasitet, rekkevidde og syklusreferanser til %1$@ fabrikkstandard.",
        "th": "การดำเนินการนี้จะรีเซ็ตความจุแบตเตอรี่ ระยะทาง และรอบชาร์จ กลับเป็นค่าเริ่มต้นจากโรงงานของ %1$@"
    },
    "This resets vehicle specifications and tariffs back to default factory specifications.": {
        "en": "This resets vehicle specifications and tariffs back to default factory specifications.",
        "de": "Setzt Fahrzeugspezifikationen und Tarife auf Werkseinstellungen zurück.",
        "fr": "Rétablit les spécifications du véhicule et les tarifs aux valeurs d'usine par défaut.",
        "es": "Esto restablece las especificaciones del vehículo y tarifas a los valores de fábrica.",
        "zh-Hans": "这会将车辆规格和电价重置为出厂默认设置。",
        "ja": "車両スペックおよび電気料金を工場出荷時のデフォルト設定にリセットします。",
        "nb": "Dette tilbakestiller kjøretøyspesifikasjoner og tariffer til fabrikkinnstillinger.",
        "th": "การดำเนินการนี้จะรีเซ็ตข้อมูลจำเพาะของรถยนต์และอัตราค่าไฟฟ้ากลับเป็นค่าเริ่มต้นจากโรงงาน"
    },
    "Time Range": {
        "en": "Time Range",
        "de": "Zeitbereich",
        "fr": "Période",
        "es": "Rango de tiempo",
        "zh-Hans": "时间范围",
        "ja": "期間",
        "nb": "Tidsperiode",
        "th": "ช่วงเวลา"
    },
    "Top Locations": {
        "en": "Top Locations",
        "de": "Häufigste Standorte",
        "fr": "Lieux principaux",
        "es": "Ubicaciones principales",
        "zh-Hans": "常去地点",
        "ja": "主な充電場所",
        "nb": "Beste steder",
        "th": "สถานที่ชาร์จยอดนิยม"
    },
    "Total Capacity Loss": {
        "en": "Total Capacity Loss",
        "de": "Gesamter Kapazitätsverlust",
        "fr": "Perte totale de capacité",
        "es": "Pérdida total de capacidad",
        "zh-Hans": "累计容量损耗",
        "ja": "総容量劣化量",
        "nb": "Totalt kapasitetstap",
        "th": "ความจุที่เสื่อมสภาพรวม"
    },
    "Total Energy": {
        "en": "Total Energy",
        "de": "Gesamtenergie",
        "fr": "Énergie totale",
        "es": "Energía total",
        "zh-Hans": "总充入电量",
        "ja": "総充電電力量",
        "nb": "Total energi",
        "th": "พลังงานทั้งหมด"
    },
    "Total Paid": {
        "en": "Total Paid",
        "de": "Gesamt bezahlt",
        "fr": "Total payé",
        "es": "Total pagado",
        "zh-Hans": "总支付金额",
        "ja": "支払総額",
        "nb": "Totalt betalt",
        "th": "ยอดชำระรวม"
    },
    "Total Spent": {
        "en": "Total Spent",
        "de": "Gesamtausgaben",
        "fr": "Total dépensé",
        "es": "Total gastado",
        "zh-Hans": "总花费",
        "ja": "総支出",
        "nb": "Totalt brukt",
        "th": "ค่าใช้จ่ายทั้งหมด"
    },
    "Total: %@": {
        "en": "Total: %1$@",
        "de": "Gesamt: %1$@",
        "fr": "Total : %1$@",
        "es": "Total: %1$@",
        "zh-Hans": "总计：%1$@",
        "ja": "合計: %1$@",
        "nb": "Totalt: %1$@",
        "th": "รวม: %1$@"
    },
    "Trends": {
        "en": "Trends",
        "de": "Trends",
        "fr": "Tendances",
        "es": "Tendencias",
        "zh-Hans": "趋势",
        "ja": "傾向",
        "nb": "Trender",
        "th": "แนวโน้ม"
    },
    "Type": {
        "en": "Type",
        "de": "Typ",
        "fr": "Type",
        "es": "Tipo",
        "zh-Hans": "类型",
        "ja": "タイプ",
        "nb": "Type",
        "th": "ประเภท"
    },
    "Units": {
        "en": "Units",
        "de": "Einheiten",
        "fr": "Unités",
        "es": "Unidades",
        "zh-Hans": "单位",
        "ja": "単位",
        "nb": "Enheter",
        "th": "หน่วยวัด"
    },
    "Units & Currency": {
        "en": "Units & Currency",
        "de": "Einheiten & Währung",
        "fr": "Unités et devise",
        "es": "Unidades y moneda",
        "zh-Hans": "单位与货币",
        "ja": "単位と通貨",
        "nb": "Enheter og valuta",
        "th": "หน่วยวัดและสกุลเงิน"
    },
    "VERIFIED": {
        "en": "VERIFIED",
        "de": "VERIFIZIERT",
        "fr": "VÉRIFIÉ",
        "es": "VERIFICADO",
        "zh-Hans": "已验证",
        "ja": "検証済み",
        "nb": "VERIFISERT",
        "th": "ตรวจสอบแล้ว"
    },
    "Vehicle": {
        "en": "Vehicle",
        "de": "Fahrzeug",
        "fr": "Véhicule",
        "es": "Vehículo",
        "zh-Hans": "车辆",
        "ja": "車両",
        "nb": "Kjøretøy",
        "th": "รถยนต์"
    },
    "Vehicle Identity": {
        "en": "Vehicle Identity",
        "de": "Fahrzeug-Identität",
        "fr": "Identité du véhicule",
        "es": "Identidad del vehículo",
        "zh-Hans": "车辆信息",
        "ja": "車両情報",
        "nb": "Kjøretøyidentitet",
        "th": "ข้อมูลประจำรถ"
    },
    "Vehicle Model": {
        "en": "Vehicle Model",
        "de": "Fahrzeugmodell",
        "fr": "Modèle du véhicule",
        "es": "Modelo del vehículo",
        "zh-Hans": "车辆型号",
        "ja": "車種・モデル",
        "nb": "Kjøretøymodell",
        "th": "รุ่นรถยนต์"
    },
    "Vehicle Name": {
        "en": "Vehicle Name",
        "de": "Fahrzeugname",
        "fr": "Nom du véhicule",
        "es": "Nombre del vehículo",
        "zh-Hans": "车辆昵称",
        "ja": "車両名",
        "nb": "Kjøretøynavn",
        "th": "ชื่อรถยนต์"
    },
    "Vendor": {
        "en": "Vendor",
        "de": "Anbieter",
        "fr": "Fournisseur",
        "es": "Proveedor",
        "zh-Hans": "充电运营商",
        "ja": "事業者",
        "nb": "Leverandør",
        "th": "ผู้ให้บริการ"
    },
    "Vs. Mileage": {
        "en": "Vs. Mileage",
        "de": "Nach Kilometerstand",
        "fr": "Selon kilométrage",
        "es": "Vs. Kilometraje",
        "zh-Hans": "按行驶里程",
        "ja": "走行距離別",
        "nb": "Mot kjørelengde",
        "th": "เทียบกับระยะทาง"
    },
    "Wall Box Power": {
        "en": "Wall Box Power",
        "de": "Wallbox-Leistung",
        "fr": "Puissance borne murale",
        "es": "Potencia de cargador de pared",
        "zh-Hans": "家用充电桩功率",
        "ja": "自宅充電器出力",
        "nb": "Veggladeeffekt",
        "th": "กำลังไฟเครื่องชาร์จบ้าน"
    },
    "Welcome to Joule ⚡️": {
        "comment": "A welcome message for the user to start using Joule.",
        "en": "Welcome to Joule ⚡️",
        "de": "Willkommen bei Joule ⚡️",
        "fr": "Bienvenue sur Joule ⚡️",
        "es": "Bienvenido a Joule ⚡️",
        "zh-Hans": "欢迎使用 Joule ⚡️",
        "ja": "Joule へようこそ ⚡️",
        "nb": "Velkommen til Joule ⚡️",
        "th": "ยินดีต้อนรับสู่ Joule ⚡️"
    },
    "Why are rates calibrating?": {
        "comment": "A label displayed in a tooltip that explains why the battery degradation rate is calibrating.",
        "en": "Why are rates calibrating?",
        "de": "Warum wird noch kalibriert?",
        "fr": "Pourquoi les taux sont-ils en cours de calibrage ?",
        "es": "¿Por qué se están calibrando las tasas?",
        "zh-Hans": "为什么衰减率显示正在校准？",
        "ja": "なぜ測定校正中なのですか？",
        "nb": "Hvorfor kalibreres ratene?",
        "th": "ทำไมถึงอยู่ในช่วงประเมินผล?"
    },
    "Work": {
        "en": "Work",
        "de": "Arbeit",
        "fr": "Travail",
        "es": "Trabajo",
        "zh-Hans": "公司/工作地",
        "ja": "職場",
        "nb": "Jobb",
        "th": "ที่ทำงาน"
    },
    "You can continue using Joule completely offline. Signing in later will safely merge your local sessions into the cloud.": {
        "en": "You can continue using Joule completely offline. Signing in later will safely merge your local sessions into the cloud.",
        "de": "Sie können Joule komplett offline nutzen. Bei späterer Anmeldung werden Ihre lokalen Daten sicher synchronisiert.",
        "fr": "Vous pouvez continuer à utiliser Joule hors ligne. Une connexion ultérieure fusionnera vos sessions dans le cloud en toute sécurité.",
        "es": "Puedes seguir usando Joule desconectado. Iniciar sesión más tarde sincronizará de forma segura tus sesiones en la nube.",
        "zh-Hans": "您可以完全离线使用 Joule。稍后登录时，系统将安全地将本地充电记录合并至云端。",
        "ja": "Joule は完全にオフラインのままでも利用できます。後でサインインすれば、ローカルのセッションが安全にクラウドへ統合されます。",
        "nb": "Du kan fortsette å bruke Joule helt frakoblet. Innlogging senere vil trygt flette dine lokale økter til skyen.",
        "th": "คุณสามารถใช้งาน Joule แบบออฟไลน์ได้อย่างสมบูรณ์ การเข้าสู่ระบบในภายหลังจะรวมรายการในเครื่องของคุณเข้ากับคลาวด์อย่างปลอดภัย"
    },
    "Your Vehicles (%@)": {
        "en": "Your Vehicles (%1$@)",
        "de": "Ihre Fahrzeuge (%1$@)",
        "fr": "Vos véhicules (%1$@)",
        "es": "Tus vehículos (%1$@)",
        "zh-Hans": "您的车辆 (%1$@)",
        "ja": "登録車両 (%1$@)",
        "nb": "Dine kjøretøy (%1$@)",
        "th": "รถยนต์ของคุณ (%1$@)"
    },
    "Your charging history is automatically synced across all your devices connected to this Google account.": {
        "en": "Your charging history is automatically synced across all your devices connected to this Google account.",
        "de": "Ihr Ladeverlauf wird automatisch auf allen mit diesem Google-Konto verbundenen Geräten synchronisiert.",
        "fr": "Votre historique de recharge est synchronisé automatiquement sur tous vos appareils connectés à ce compte Google.",
        "es": "Tu historial de carga se sincroniza automáticamente en todos tus dispositivos conectados a esta cuenta de Google.",
        "zh-Hans": "您的充电记录将自动在连接至此 Google 账号的所有设备间保持同步。",
        "ja": "充電履歴は、この Google アカウントに接続されているすべてのデバイス間で自動的に同期されます。",
        "nb": "Ladehistorikken din synkroniseres automatisk på tvers av alle enheter som er koblet til denne Google-kontoen.",
        "th": "ประวัติการชาร์จของคุณจะถูกซิงค์โดยอัตโนมัติบนอุปกรณ์ทั้งหมดที่เชื่อมต่อกับบัญชี Google นี้"
    },
    "Your history will remain safely stored in the cloud.": {
        "en": "Your history will remain safely stored in the cloud.",
        "de": "Ihr Verlauf bleibt sicher in der Cloud gespeichert.",
        "fr": "Votre historique restera stocké en toute sécurité dans le cloud.",
        "es": "Tu historial permanecerá guardado de forma segura en la nube.",
        "zh-Hans": "您的历史记录将安全地保存在云端。",
        "ja": "履歴は安全にクラウドに保存されます。",
        "nb": "Historikken din forblir trygt lagret i skyen.",
        "th": "ประวัติของคุณจะยังคงถูกจัดเก็บอย่างปลอดภัยบนคลาวด์"
    },
    "Battery SoC": {
        "en": "Battery SoC",
        "de": "Batterie-SoC",
        "fr": "SoC de la batterie",
        "es": "SoC de batería",
        "zh-Hans": "电池电量 (SoC)",
        "ja": "バッテリー充電率 (SoC)",
        "nb": "Batteri-SoC",
        "th": "ระดับแบตเตอรี่ (SoC)"
    },
    "Start SoC": {
        "en": "Start SoC",
        "de": "Start-SoC",
        "fr": "SoC de départ",
        "es": "SoC inicial",
        "zh-Hans": "起始电量 (SoC)",
        "ja": "開始時SoC",
        "nb": "Start-SoC",
        "th": "SoC เริ่มต้น"
    },
    "End SoC": {
        "en": "End SoC",
        "de": "End-SoC",
        "fr": "SoC de fin",
        "es": "SoC final",
        "zh-Hans": "结束电量 (SoC)",
        "ja": "終了時SoC",
        "nb": "Slutt-SoC",
        "th": "SoC สิ้นสุด"
    },
    "Speed Balance": {
        "en": "Speed Balance",
        "de": "Geschwindigkeits-Balance",
        "fr": "Équilibre de vitesse",
        "es": "Equilibrio de velocidad",
        "zh-Hans": "充电速度均衡",
        "ja": "充電速度バランス",
        "nb": "Hastighetsbalanse",
        "th": "ความสมดุลความเร็วชาร์จ"
    },
    "Discharge Floor": {
        "en": "Discharge Floor",
        "de": "Entladegrenze",
        "fr": "Seuil de décharge",
        "es": "Límite de descarga",
        "zh-Hans": "放电下限保护",
        "ja": "放電下限バッファ",
        "nb": "Utladingsgrense",
        "th": "ระดับคายประจุต่ำสุด"
    },
    "Cycle Regularity": {
        "en": "Cycle Regularity",
        "de": "Zyklus-Regelmäßigkeit",
        "fr": "Régularité des cycles",
        "es": "Regularidad de ciclos",
        "zh-Hans": "循环规律性",
        "ja": "サイクル規則性",
        "nb": "Syklusregularitet",
        "th": "ความสม่ำเสมอของรอบชาร์จ"
    },
    "100% Calibration": {
        "en": "100% Calibration",
        "de": "100% Kalibrierung",
        "fr": "Calibration à 100 %",
        "es": "Calibración al 100%",
        "zh-Hans": "100% 校准",
        "ja": "100% 校正",
        "nb": "100 % kalibrering",
        "th": "การปรับเทียบ 100%"
    },
    "Daily SoC Ceiling": {
        "en": "Daily SoC Ceiling",
        "de": "Tägliche SoC-Obergrenze",
        "fr": "Plafond quotidien de SoC",
        "es": "Límite diario de SoC",
        "zh-Hans": "日常电量上限",
        "ja": "日常SoC上限",
        "nb": "Daglig SoC-tak",
        "th": "ขีดจำกัด SoC รายวัน"
    },
    "Usable Capacity": {
        "en": "Usable Capacity",
        "de": "Nutzbare Kapazität",
        "fr": "Capacité utilisable",
        "es": "Capacidad utilizable",
        "zh-Hans": "可用容量",
        "ja": "利用可能容量",
        "nb": "Brukbar kapasitet",
        "th": "ความจุที่ใช้งานได้"
    },
    "Full Cycles": {
        "en": "Full Cycles",
        "de": "Volle Zyklen",
        "fr": "Cycles complets",
        "es": "Ciclos completos",
        "zh-Hans": "完整循环次数",
        "ja": "フル充電サイクル",
        "nb": "Fulle sykluser",
        "th": "รอบชาร์จเต็ม (EFC)"
    },
    "Fast Charge Ratio": {
        "en": "Fast Charge Ratio",
        "de": "Schnelllade-Verhältnis",
        "fr": "Ratio de charge rapide",
        "es": "Proporción de carga rápida",
        "zh-Hans": "快充比例",
        "ja": "急速充電比率",
        "nb": "Hurtigladeforhold",
        "th": "สัดส่วนการชาร์จเร็ว"
    },
    "Scan Receipt or Meter": {
        "en": "Scan Receipt or Meter",
        "de": "Beleg oder Display scannen",
        "fr": "Scanner le reçu ou l'écran",
        "es": "Escanear recibo o pantalla",
        "zh-Hans": "扫描收据或充电桩屏幕",
        "ja": "レシート・画面をスキャン",
        "nb": "Skann kvittering eller skjerm",
        "th": "สแกนใบเสร็จหรือหน้าจอตู้ชาร์จ"
    },
    "Analyzing receipt text…": {
        "en": "Analyzing receipt text…",
        "de": "Belegtext wird analysiert…",
        "fr": "Analyse du reçu en cours…",
        "es": "Analizando texto del recibo…",
        "zh-Hans": "正在分析收据文本…",
        "ja": "テキストを解析中…",
        "nb": "Analyserer kvitteringstekst…",
        "th": "กำลังวิเคราะห์ข้อความ…"
    },
    "Could not load the selected image.": {
        "en": "Could not load the selected image.",
        "de": "Das ausgewählte Bild konnte nicht geladen werden.",
        "fr": "Impossible de charger l'image sélectionnée.",
        "es": "No se pudo cargar la imagen seleccionada.",
        "zh-Hans": "无法加载所选图片。",
        "ja": "選択した画像を読み込めませんでした。",
        "nb": "Kunne ikke laste det valgte bildet.",
        "th": "ไม่สามารถโหลดรูปภาพที่เลือกได้"
    },
    "Invalid image data.": {
        "en": "Invalid image data.",
        "de": "Ungültige Bilddaten.",
        "fr": "Données d'image non valides.",
        "es": "Datos de imagen no válidos.",
        "zh-Hans": "无效的图片数据。",
        "ja": "無効な画像データです。",
        "nb": "Ugyldige bildedata.",
        "th": "ข้อมูลรูปภาพไม่ถูกต้อง"
    },
    "No text recognized.": {
        "en": "No text recognized.",
        "de": "Kein Text erkannt.",
        "fr": "Aucun texte reconnu.",
        "es": "No se reconoció texto.",
        "zh-Hans": "未识别到任何文本。",
        "ja": "テキストを認識できませんでした。",
        "nb": "Ingen tekst gjenkjent.",
        "th": "ไม่พบข้อความในรูปภาพ"
    },
    "No charging metrics could be detected in this photo. You can enter values manually.": {
        "en": "No charging metrics could be detected in this photo. You can enter values manually.",
        "de": "Es konnten keine Ladedaten erkannt werden. Sie können die Werte manuell eingeben.",
        "fr": "Aucune métrique de charge détectée. Vous pouvez saisir les valeurs manuellement.",
        "es": "No se detectaron métricas de carga en esta foto. Puede ingresar los valores manualmente.",
        "zh-Hans": "未在照片中检测到充电数据，您可以手动输入数值。",
        "ja": "写真から充電データを検出できませんでした。手動で入力してください。",
        "nb": "Ingen lademålinger ble funnet i dette bildet. Du kan legge inn verdiene manuelt.",
        "th": "ไม่พบข้อมูลการชาร์จในรูปภาพนี้ คุณสามารถกรอกข้อมูลด้วยตนเองได้"
    },
    "Estimated Pack Capacity": {
        "en": "Estimated Pack Capacity",
        "de": "Geschätzte Akkukapazität",
        "fr": "Capacité estimée de la batterie",
        "es": "Capacidad estimada de la batería",
        "zh-Hans": "预估电池组容量",
        "ja": "推定バッテリーパック容量",
        "nb": "Estimert batteripakkekapasitet",
        "th": "ความจุแบตเตอรี่โดยประมาณ"
    },
    "New Charging Session": {
        "en": "New Charging Session",
        "de": "Neuer Ladevorgang",
        "fr": "Nouvelle session de recharge",
        "es": "Nueva sesión de carga",
        "zh-Hans": "记录新充电",
        "ja": "新規充電セッション",
        "nb": "Ny ladeøkt",
        "th": "บันทึกการชาร์จใหม่"
    },
    "Sign In with Google": {
        "en": "Sign In with Google",
        "de": "Mit Google anmelden",
        "fr": "Se connecter avec Google",
        "es": "Iniciar sesión con Google",
        "zh-Hans": "使用 Google 登录",
        "ja": "Googleでサインイン",
        "nb": "Logg på med Google",
        "th": "ลงชื่อเข้าใช้ด้วย Google"
    },
    "History Options": {
        "en": "History Options",
        "de": "Verlaufsoptionen",
        "fr": "Options de l'historique",
        "es": "Opciones de historial",
        "zh-Hans": "历史记录选项",
        "ja": "履歴オプション",
        "nb": "Historikkvalg",
        "th": "ตัวเลือกประวัติ"
    },
    "Default Vehicle": {
        "en": "Default Vehicle",
        "de": "Standardfahrzeug",
        "fr": "Véhicule par défaut",
        "es": "Vehículo predeterminado",
        "zh-Hans": "默认车辆",
        "ja": "デフォルト車両",
        "nb": "Standardkjøretøy",
        "th": "รถยนต์ค่าเริ่มต้น"
    },
    "Deferred to Electric Bill This Month": {
        "en": "Deferred to Electric Bill This Month",
        "de": "Diesen Monat auf Stromrechnung verbucht",
        "fr": "Reporté sur la facture d'électricité ce mois-ci",
        "es": "Diferido a la factura de luz este mes",
        "zh-Hans": "本月计入家庭电费",
        "ja": "今月の電気料金請求分",
        "nb": "Utsatt til strømregning denne måneden",
        "th": "ยอดชำระรวมในบิลค่าไฟเดือนนี้"
    },
    "Dashboard Overview Hero Card": {
        "en": "Dashboard Overview Hero Card",
        "de": "Übersichtskarte",
        "fr": "Carte principale du tableau de bord",
        "es": "Tarjeta principal del panel",
        "zh-Hans": "仪表板概览卡片",
        "ja": "ダッシュボード概要カード",
        "nb": "Oversiktskort for dashbord",
        "th": "การ์ดสรุปภาพรวมแดชบอร์ด"
    },
    "Monthly Charging Cost Trend": {
        "en": "Monthly Charging Cost Trend",
        "de": "Monatlicher Ladekosten-Trend",
        "fr": "Tendance mensuelle du coût de recharge",
        "es": "Tendencia mensual de costes de carga",
        "zh-Hans": "每月充电花费趋势",
        "ja": "月間充電コスト推移",
        "nb": "Månedlig ladekostnadstrend",
        "th": "แนวโน้มค่าชาร์จรายเดือน"
    },
    "Monthly Energy Breakdown by Charging Type": {
        "en": "Monthly Energy Breakdown by Charging Type",
        "de": "Monatliche Energie nach Ladetyp",
        "fr": "Répartition mensuelle de l'énergie par type de charge",
        "es": "Desglose mensual de energía por tipo de carga",
        "zh-Hans": "每月各类型充电电量分布",
        "ja": "充電タイプ別月間電力量",
        "nb": "Månedlig energifordeling etter ladetype",
        "th": "สัดส่วนพลังงานรายเดือนตามประเภทการชาร์จ"
    },
    "Monthly Energy by Type (kWh)": {
        "en": "Monthly Energy by Type (kWh)",
        "de": "Monatliche Energie nach Typ (kWh)",
        "fr": "Énergie mensuelle par type (kWh)",
        "es": "Energía mensual por tipo (kWh)",
        "zh-Hans": "每月各类型电量 (kWh)",
        "ja": "月間電力量（kWh）",
        "nb": "Månedlig energi etter type (kWh)",
        "th": "พลังงานรายเดือนตามประเภท (kWh)"
    },
    "Monthly charging cost": {
        "en": "Monthly charging cost",
        "de": "Monatliche Ladekosten",
        "fr": "Coût mensuel de recharge",
        "es": "Coste mensual de carga",
        "zh-Hans": "每月充电花费",
        "ja": "月間充電コスト",
        "nb": "Månedlig ladekostnad",
        "th": "ค่าชาร์จรายเดือน"
    },
    "Driving Efficiency Trend": {
        "en": "Driving Efficiency Trend",
        "de": "Fahreffizienz-Trend",
        "fr": "Tendance de l'efficacité énergétique",
        "es": "Tendencia de eficiencia de conducción",
        "zh-Hans": "行驶能耗效率趋势",
        "ja": "電費効率推移",
        "nb": "Kjøreeffektivitetstrend",
        "th": "แนวโน้มประสิทธิภาพการขับขี่"
    },
    "State of Health Over Time": {
        "en": "State of Health Over Time",
        "de": "Batteriezustand (SoH) im Zeitverlauf",
        "fr": "État de santé (SoH) au fil du temps",
        "es": "Estado de salud (SoH) a lo largo del tiempo",
        "zh-Hans": "电池健康度 (SoH) 随时间变化",
        "ja": "バッテリー健全度 (SoH) の推移",
        "nb": "Batterihelse (SoH) over tid",
        "th": "สุขภาพแบตเตอรี่ (SoH) ตามช่วงเวลา"
    },
    "State of Health Versus Mileage": {
        "en": "State of Health Versus Mileage",
        "de": "Batteriezustand (SoH) nach Kilometerstand",
        "fr": "État de santé (SoH) selon le kilométrage",
        "es": "Estado de salud (SoH) frente a kilometraje",
        "zh-Hans": "电池健康度 (SoH) 与行驶里程",
        "ja": "走行距離に対する健全度 (SoH)",
        "nb": "Batterihelse (SoH) mot kjørelengde",
        "th": "สุขภาพแบตเตอรี่ (SoH) เทียบกับระยะทาง"
    },
    "Projected 100% Driving Range Over Time": {
        "en": "Projected 100% Driving Range Over Time",
        "de": "Prognostizierte 100% Reichweite im Zeitverlauf",
        "fr": "Autonomie estimée à 100 % au fil du temps",
        "es": "Autonomía proyectada al 100% a lo largo del tiempo",
        "zh-Hans": "预估 100% 满电续航随时间变化",
        "ja": "推定100%航続距離の推移",
        "nb": "Beregnet 100 % rekkevidde over tid",
        "th": "ระยะทางวิ่งที่ 100% โดยประมาณตามช่วงเวลา"
    },
    "Cycle Wear Versus Chemistry Benchmark": {
        "en": "Cycle Wear Versus Chemistry Benchmark",
        "de": "Zyklusabnutzung im Vergleich zum Chemiestandard",
        "fr": "Usure des cycles par rapport à la référence chimique",
        "es": "Desgaste de ciclos frente a referencia química",
        "zh-Hans": "循环衰减对比化学基准",
        "ja": "化学仕様ベンチマークとのサイクル比較",
        "nb": "Syklusslitasje mot kjemisk referanse",
        "th": "การเสื่อมของรอบชาร์จเทียบกับเกณฑ์แบตเตอรี่"
    },
    "Open EV Battery Charging Best Practices Guide": {
        "en": "Open EV Battery Charging Best Practices Guide",
        "de": "Leitfaden für optimale Ladevorgänge öffnen",
        "fr": "Ouvrir le guide des bonnes pratiques de recharge",
        "es": "Abrir guía de buenas prácticas de carga",
        "zh-Hans": "打开电动汽车电池充电最佳实践指南",
        "ja": "EVバッテリー充電ベストプラクティスガイドを開く",
        "nb": "Åpne veiledning for beste ladepraksis",
        "th": "เปิดคู่มือข้อแนะนำการชาร์จแบตเตอรี่ EV"
    },
    "View detailed battery health analytics": {
        "en": "View detailed battery health analytics",
        "de": "Detaillierte Batterieanalysen ansehen",
        "fr": "Afficher les analyses détaillées de la batterie",
        "es": "Ver análisis detallados de salud de la batería",
        "zh-Hans": "查看详细的电池健康分析",
        "ja": "詳細なバッテリー健康分析を表示",
        "nb": "Vis detaljert batterihelseanalyse",
        "th": "ดูการวิเคราะห์สุขภาพแบตเตอรี่อย่างละเอียด"
    },
    "Log a new charging session": {
        "en": "Log a new charging session",
        "de": "Einen neuen Ladevorgang erfassen",
        "fr": "Enregistrer une nouvelle session de recharge",
        "es": "Registrar una nueva sesión de carga",
        "zh-Hans": "记录新的充电记录",
        "ja": "新しい充電セッションを記録",
        "nb": "Loggfør en ny ladeøkt",
        "th": "บันทึกข้อมูลการชาร์จครั้งใหม่"
    },
    "%lld Duplicate Sessions Found": {
        "en": "%1$lld Duplicate Sessions Found",
        "de": "%1$lld doppelte Ladevorgänge gefunden",
        "fr": "%1$lld sessions en double trouvées",
        "es": "%1$lld sesiones duplicadas encontradas",
        "zh-Hans": "发现 %1$lld 条重复记录",
        "ja": "%1$lld 件の重複セッションが見つかりました",
        "nb": "%1$lld duplikate ladeøkter funnet",
        "th": "พบข้อมูลการชาร์จซ้ำ %1$lld รายการ"
    },
    "%lld Duplicate Session Found": {
        "en": "%1$lld Duplicate Session Found",
        "de": "%1$lld doppelter Ladevorgang gefunden",
        "fr": "%1$lld session en double trouvée",
        "es": "%1$lld sesión duplicada encontrada",
        "zh-Hans": "发现 %1$lld 条重复记录",
        "ja": "%1$lld 件の重複セッションが見つかりました",
        "nb": "%1$lld duplikat ladeøkt funnet",
        "th": "พบข้อมูลการชาร์จซ้ำ %1$lld รายการ"
    },
    "Clean Up Duplicates (%lld)": {
        "en": "Clean Up Duplicates (%1$lld)",
        "de": "Duplikate bereinigen (%1$lld)",
        "fr": "Nettoyer les doublons (%1$lld)",
        "es": "Limpiar duplicados (%1$lld)",
        "zh-Hans": "清理重复项 (%1$lld)",
        "ja": "重複を整理 (%1$lld)",
        "nb": "Rydd opp i duplikater (%1$lld)",
        "th": "ลบรายการซ้ำ (%1$lld)"
    },
    "Manage Garage (%lld)": {
        "en": "Manage Garage (%1$lld)",
        "de": "Garage verwalten (%1$lld)",
        "fr": "Gérer le garage (%1$lld)",
        "es": "Administrar garaje (%1$lld)",
        "zh-Hans": "车库管理 (%1$lld)",
        "ja": "ガレージ管理 (%1$lld)",
        "nb": "Administrer garasje (%1$lld)",
        "th": "จัดการโรงรถ (%1$lld)"
    },
    "Manage Garage (%lld)…": {
        "en": "Manage Garage (%1$lld)…",
        "de": "Garage verwalten (%1$lld)…",
        "fr": "Gérer le garage (%1$lld)…",
        "es": "Administrar garaje (%1$lld)…",
        "zh-Hans": "车库管理 (%1$lld)…",
        "ja": "ガレージ管理 (%1$lld)…",
        "nb": "Administrer garasje (%1$lld)…",
        "th": "จัดการโรงรถ (%1$lld)…"
    },
    "Your Vehicles (%lld)": {
        "en": "Your Vehicles (%1$lld)",
        "de": "Ihre Fahrzeuge (%1$lld)",
        "fr": "Vos véhicules (%1$lld)",
        "es": "Sus vehículos (%1$lld)",
        "zh-Hans": "您的车辆 (%1$lld)",
        "ja": "登録車両 (%1$lld)",
        "nb": "Dine kjøretøy (%1$lld)",
        "th": "รถยนต์ของคุณ (%1$lld)"
    },
    "%1$lld sessions (%2$.0f kWh)": {
        "en": "%1$lld sessions (%2$.0f kWh)",
        "de": "%1$lld Ladevorgänge (%2$.0f kWh)",
        "fr": "%1$lld sessions (%2$.0f kWh)",
        "es": "%1$lld sesiones (%2$.0f kWh)",
        "zh-Hans": "%1$lld 次充电 (%2$.0f kWh)",
        "ja": "%1$lld 回のセッション (%2$.0f kWh)",
        "nb": "%1$lld økter (%2$.0f kWh)",
        "th": "%1$lld ครั้ง (%2$.0f kWh)"
    },
    "%1$lld sessions • %2$.0f kWh": {
        "en": "%1$lld sessions • %2$.0f kWh",
        "de": "%1$lld Ladevorgänge • %2$.0f kWh",
        "fr": "%1$lld sessions • %2$.0f kWh)",
        "es": "%1$lld sesiones • %2$.0f kWh",
        "zh-Hans": "%1$lld 次充电 • %2$.0f kWh",
        "ja": "%1$lld 回のセッション • %2$.0f kWh",
        "nb": "%1$lld økter • %2$.0f kWh",
        "th": "%1$lld ครั้ง • %2$.0f kWh"
    },
    "%lld sessions analyzed": {
        "en": "%1$lld sessions analyzed",
        "de": "%1$lld Ladevorgänge analysiert",
        "fr": "%1$lld sessions analysées",
        "es": "%1$lld sesiones analizadas",
        "zh-Hans": "已分析 %1$lld 次记录",
        "ja": "%1$lld 件のセッションを分析",
        "nb": "%1$lld økter analysert",
        "th": "วิเคราะห์จาก %1$lld ครั้ง"
    },
    "%lld tips": {
        "en": "%1$lld tips",
        "de": "%1$lld Tipps",
        "fr": "%1$lld conseils",
        "es": "%1$lld consejos",
        "zh-Hans": "%1$lld 条建议",
        "ja": "%1$lld 件のヒント",
        "nb": "%1$lld tips",
        "th": "%1$lld คำแนะนำ"
    },
    "%lld found": {
        "en": "%1$lld found",
        "de": "%1$lld gefunden",
        "fr": "%1$lld trouvé(s)",
        "es": "%1$lld encontrados",
        "zh-Hans": "找到 %1$lld 条",
        "ja": "%1$lld 件検出",
        "nb": "%1$lld funnet",
        "th": "พบ %1$lld รายการ"
    },
    "Nominal: %.1f kWh": {
        "en": "Nominal: %1$.1f kWh",
        "de": "Nennwert: %1$.1f kWh",
        "fr": "Nominal : %1$.1f kWh",
        "es": "Nominal: %1$.1f kWh",
        "zh-Hans": "标称容量: %1$.1f kWh",
        "ja": "定格容量: %1$.1f kWh",
        "nb": "Nominell: %1$.1f kWh",
        "th": "ความจุโรงงาน: %1$.1f kWh"
    },
    "Saved %@": {
        "en": "Saved %1$@",
        "de": "%1$@ gespart",
        "fr": "%1$@ économisés",
        "es": "%1$@ ahorrados",
        "zh-Hans": "已节省 %1$@",
        "ja": "%1$@ 節約",
        "nb": "Spart %1$@",
        "th": "ประหยัด %1$@"
    },
    "per %@": {
        "en": "per %1$@",
        "de": "pro %1$@",
        "fr": "par %1$@",
        "es": "por %1$@",
        "zh-Hans": "每 %1$@",
        "ja": "/ %1$@",
        "nb": "per %1$@",
        "th": "ต่อ %1$@"
    },
    "per kWh": {
        "en": "per kWh",
        "de": "pro kWh",
        "fr": "par kWh",
        "es": "por kWh",
        "zh-Hans": "每 kWh",
        "ja": "/ kWh",
        "nb": "per kWh",
        "th": "ต่อ kWh"
    },
    "%lld vehicles combined": {
        "en": "%1$lld vehicles combined",
        "de": "%1$lld Fahrzeuge kombiniert",
        "fr": "%1$lld véhicules combinés",
        "es": "%1$lld vehículos combinados",
        "zh-Hans": "共 %1$lld 辆车汇总",
        "ja": "%1$lld 台の合計",
        "nb": "%1$lld kjøretøy samlet",
        "th": "รวมทั้งหมด %1$lld คัน"
    },
    "%.0f kWh nominal • ~%.0f %@": {
        "en": "%1$.0f kWh nominal • ~%2$.0f %3$@",
        "de": "%1$.0f kWh Nennwert • ~%2$.0f %3$@",
        "fr": "%1$.0f kWh nominal • ~%2$.0f %3$@",
        "es": "%1$.0f kWh nominal • ~%2$.0f %3$@",
        "zh-Hans": "%1$.0f kWh 标称 • ~%2$.0f %3$@",
        "ja": "定格 %1$.0f kWh • 約 %2$.0f %3$@",
        "nb": "%1$.0f kWh nominell • ~%2$.0f %3$@",
        "th": "ความจุ %1$.0f kWh • ~%2$.0f %3$@"
    },
    "%.1f of %.0f kWh": {
        "en": "%1$.1f of %2$.0f kWh",
        "de": "%1$.1f von %2$.0f kWh",
        "fr": "%1$.1f sur %2$.0f kWh",
        "es": "%1$.1f de %2$.0f kWh",
        "zh-Hans": "%1$.1f / %2$.0f kWh",
        "ja": "%1$.1f / %2$.0f kWh",
        "nb": "%1$.1f av %2$.0f kWh",
        "th": "%1$.1f จาก %2$.0f kWh"
    },
    "Driving Eff. (100%@)": {
        "en": "Driving Eff. (100%1$@)",
        "de": "Fahreffizienz (100%1$@)",
        "fr": "Efficacité (100 %1$@)",
        "es": "Eficiencia (100 %1$@)",
        "zh-Hans": "百公里能耗 (100%1$@)",
        "ja": "電費 (100%1$@)",
        "nb": "Kjøreeffektivitet (100 %1$@)",
        "th": "อัตราสิ้นเปลือง (100%1$@)"
    },
    "Consumption (100%@)": {
        "en": "Consumption (100%1$@)",
        "de": "Verbrauch (100%1$@)",
        "fr": "Consommation (100 %1$@)",
        "es": "Consumo (100 %1$@)",
        "zh-Hans": "百公里能耗 (100%1$@)",
        "ja": "消費率 (100%1$@)",
        "nb": "Forbruk (100 %1$@)",
        "th": "อัตราการใช้พลังงาน (100%1$@)"
    },
    "Monthly Cost (%@)": {
        "en": "Monthly Cost (%1$@)",
        "de": "Monatliche Kosten (%1$@)",
        "fr": "Coût mensuel (%1$@)",
        "es": "Coste mensual (%1$@)",
        "zh-Hans": "每月花费 (%1$@)",
        "ja": "月間コスト (%1$@)",
        "nb": "Månedlig kostnad (%1$@)",
        "th": "ค่าใช้จ่ายรายเดือน (%1$@)"
    },
    "%1$@ (%2$@) Battery Care": {
        "en": "%1$@ (%2$@) Battery Care",
        "de": "%1$@ (%2$@) Batteriepflege",
        "fr": "Entretien de la batterie %1$@ (%2$@)",
        "es": "Cuidado de batería %1$@ (%2$@)",
        "zh-Hans": "%1$@ (%2$@) 电池保养",
        "ja": "%1$@ (%2$@) バッテリーケア",
        "nb": "%1$@ (%2$@) Batteripleie",
        "th": "การดูแลแบตเตอรี่ %1$@ (%2$@)"
    },
    "Charging on %1$@ saved you %2$@ this month compared to peak daytime rates (%3$.1f kWh logged).": {
        "en": "Charging on %1$@ saved you %2$@ this month compared to peak daytime rates (%3$.1f kWh logged).",
        "de": "Durch Laden mit %1$@ haben Sie diesen Monat %2$@ gegenüber Spitzenzeiten gespart (%3$.1f kWh erfasst).",
        "fr": "Recharger sur %1$@ vous a fait économiser %2$@ ce mois-ci par rapport aux heures pleines (%3$.1f kWh enregistrés).",
        "es": "Cargar en %1$@ le ahorró %2$@ este mes en comparación con horas punta (%3$.1f kWh registrados).",
        "zh-Hans": "通过 %1$@ 谷段充电，本月相比高峰电价已为您节省 %2$@（记录电量 %3$.1f kWh）。",
        "ja": "%1$@ での充電により、今月のピーク時間帯料金と比べて %2$@ 節約できました（記録電力量: %3$.1f kWh）。",
        "nb": "Lading med %1$@ sparte deg for %2$@ denne måneden sammenlignet med topplastpriser (%3$.1f kWh registrert).",
        "th": "การชาร์จด้วย %1$@ ช่วยคุณประหยัด %2$@ ในเดือนนี้เมื่อเทียบกับค่าไฟช่วง Peak (บันทึกไฟไป %3$.1f kWh)"
    },
    "Baseline: %1$@ @ %2$@": {
        "en": "Baseline: %1$@ @ %2$@",
        "de": "Vergleichsbasis: %1$@ @ %2$@",
        "fr": "Référence : %1$@ @ %2$@",
        "es": "Referencia: %1$@ @ %2$@",
        "zh-Hans": "对比基准: %1$@ @ %2$@",
        "ja": "比較基準: %1$@ @ %2$@",
        "nb": "Sammenligningsgrunnlag: %1$@ @ %2$@",
        "th": "เกณฑ์เปรียบเทียบ: %1$@ @ %2$@"
    },
    "%dm ago": {
        "en": "%1$dm ago",
        "de": "vor %1$d Min.",
        "fr": "il y a %1$d min",
        "es": "hace %1$d m",
        "zh-Hans": "%1$d 分钟前",
        "ja": "%1$d分前",
        "nb": "%1$d m siden",
        "th": "%1$d นาทีที่แล้ว"
    },
    "%dh ago": {
        "en": "%1$dh ago",
        "de": "vor %1$d Std.",
        "fr": "il y a %1$d h",
        "es": "hace %1$d h",
        "zh-Hans": "%1$d 小时前",
        "ja": "%1$d時間前",
        "nb": "%1$d t siden",
        "th": "%1$d ชม. ที่แล้ว"
    },
    "%dd ago": {
        "en": "%1$dd ago",
        "de": "vor %1$d T.",
        "fr": "il y a %1$d j",
        "es": "hace %1$d d",
        "zh-Hans": "%1$d 天前",
        "ja": "%1$d日前",
        "nb": "%1$d d siden",
        "th": "%1$d วันที่แล้ว"
    },
    "Last 100%: %lld days ago": {
        "en": "Last 100%: %1$lld days ago",
        "de": "Zuletzt 100%: vor %1$lld Tagen",
        "fr": "Dernier 100 % : il y a %1$lld jours",
        "es": "Último 100%: hace %1$lld días",
        "zh-Hans": "上次满电: %1$lld 天前",
        "ja": "前回の100%充電: %1$lld 日前",
        "nb": "Sist 100 %: %1$lld dager siden",
        "th": "ชาร์จเต็ม 100% ล่าสุด: %1$lld วันก่อน"
    },
    "It has been over %lld days since your last 100% charge.": {
        "en": "It has been over %1$lld days since your last 100%% charge.",
        "de": "Seit der letzten 100%%-Ladung sind über %1$lld Tage vergangen.",
        "fr": "Cela fait plus de %1$lld jours depuis votre dernière charge à 100 %%.",
        "es": "Han pasado más de %1$lld días desde su última carga al 100 %%.",
        "zh-Hans": "距离您上次充满 100%% 已超过 %1$lld 天。",
        "ja": "前回の100%%充電から %1$lld 日以上が経過しています。",
        "nb": "Det har gått over %1$lld dager siden forrige 100 %% lading.",
        "th": "ผ่านไปแล้วกว่า %1$lld วันนับจากการชาร์จ 100%% ครั้งล่าสุดของคุณ"
    },
    "Your LFP pack was last charged to 100% %lld days ago.": {
        "en": "Your LFP pack was last charged to 100%% %1$lld days ago.",
        "de": "Ihr LFP-Akku wurde vor %1$lld Tagen zuletzt auf 100%% geladen.",
        "fr": "Votre batterie LFP a été rechargée à 100 %% pour la dernière fois il y a %1$lld jours.",
        "es": "Su batería LFP se cargó al 100 %% por última vez hace %1$lld días.",
        "zh-Hans": "您的 LFP 电池上次充满 100%% 是在 %1$lld 天前。",
        "ja": "LFPバッテリーが最後に100%%まで充電されたのは %1$lld 日前です。",
        "nb": "LFP-batteriet ble sist ladet til 100 %% for %1$lld dager siden.",
        "th": "แบตเตอรี่ LFP ของคุณชาร์จเต็ม 100%% ล่าสุดเมื่อ %1$lld วันที่แล้ว"
    },
    "Grand Total Claim: %1$@  (%2$.2f kWh total)": {
        "en": "Grand Total Claim: %1$@  (%2$.2f kWh total)",
        "de": "Gesamterstattungsbetrag: %1$@  (insgesamt %2$.2f kWh)",
        "fr": "Montant total réclamé : %1$@  (%2$.2f kWh au total)",
        "es": "Reclamación total: %1$@  (%2$.2f kWh en total)",
        "zh-Hans": "报销总额: %1$@  (累计 %2$.2f kWh)",
        "ja": "請求総額: %1$@  (合計 %2$.2f kWh)",
        "nb": "Totalt refusjonsbeløp: %1$@  (totalt %2$.2f kWh)",
        "th": "ยอดรวมเบิกจ่ายทั้งสิ้น: %1$@  (รวม %2$.2f kWh)"
    },
    "TOTAL (%@)": {
        "en": "TOTAL (%1$@)",
        "de": "GESAMT (%1$@)",
        "fr": "TOTAL (%1$@)",
        "es": "TOTAL (%1$@)",
        "zh-Hans": "总计 (%1$@)",
        "ja": "合計 (%1$@)",
        "nb": "TOTALT (%1$@)",
        "th": "รวม (%1$@)"
    },
    "Mid-Size SUV / Crossover (%.1f km/L)": {
        "en": "Mid-Size SUV / Crossover (%1$.1f km/L)",
        "de": "Mittelklasse-SUV / Crossover (%1$.1f km/L)",
        "fr": "SUV compact / Crossover (%1$.1f km/L)",
        "es": "SUV mediano / Crossover (%1$.1f km/L)",
        "zh-Hans": "中型 SUV / 跨界车 (%1$.1f km/L)",
        "ja": "中型SUV / クロスオーバー (%1$.1f km/L)",
        "nb": "Mellomstor SUV / Crossover (%1$.1f km/L)",
        "th": "SUV ขนาดกลาง / Crossover (%1$.1f กม./ลิตร)"
    },
    "Compact Sedan / Eco Car (%.1f km/L)": {
        "en": "Compact Sedan / Eco Car (%1$.1f km/L)",
        "de": "Kompaktlimousine / Eco-Auto (%1$.1f km/L)",
        "fr": "Berline compacte / Éco (%1$.1f km/L)",
        "es": "Sedán compacto / Coche ecológico (%1$.1f km/L)",
        "zh-Hans": "紧凑型轿车 / 节能车 (%1$.1f km/L)",
        "ja": "コンパクトセダン / エコカー (%1$.1f km/L)",
        "nb": "Kompakt sedan / Økobil (%1$.1f km/L)",
        "th": "ซีดานขนาดเล็ก / อีโคคาร์ (%1$.1f กม./ลิตร)"
    },
    "Full-Size SUV / Truck (%.1f km/L)": {
        "en": "Full-Size SUV / Truck (%1$.1f km/L)",
        "de": "Großer SUV / Pick-up (%1$.1f km/L)",
        "fr": "Grand SUV / Pick-up (%1$.1f km/L)",
        "es": "SUV grande / Camioneta (%1$.1f km/L)",
        "zh-Hans": "大型 SUV / 皮卡 (%1$.1f km/L)",
        "ja": "大型SUV / トラック (%1$.1f km/L)",
        "nb": "Stor SUV / Varebil (%1$.1f km/L)",
        "th": "SUV ขนาดใหญ่ / รถกระบะ (%1$.1f กม./ลิตร)"
    },
    "Mid-Size SUV / Crossover (%.1f MPG)": {
        "en": "Mid-Size SUV / Crossover (%1$.1f MPG)",
        "de": "Mittelklasse-SUV / Crossover (%1$.1f MPG)",
        "fr": "SUV compact / Crossover (%1$.1f MPG)",
        "es": "SUV mediano / Crossover (%1$.1f MPG)",
        "zh-Hans": "中型 SUV / 跨界车 (%1$.1f MPG)",
        "ja": "中型SUV / クロスオーバー (%1$.1f MPG)",
        "nb": "Mellomstor SUV / Crossover (%1$.1f MPG)",
        "th": "SUV ขนาดกลาง / Crossover (%1$.1f MPG)"
    },
    "Compact Sedan / Eco Car (%.1f MPG)": {
        "en": "Compact Sedan / Eco Car (%1$.1f MPG)",
        "de": "Kompaktlimousine / Eco-Auto (%1$.1f MPG)",
        "fr": "Berline compacte / Éco (%1$.1f MPG)",
        "es": "Sedán compacto / Coche ecológico (%1$.1f MPG)",
        "zh-Hans": "紧凑型轿车 / 节能车 (%1$.1f MPG)",
        "ja": "コンパクトセダン / エコカー (%1$.1f MPG)",
        "nb": "Kompakt sedan / Økobil (%1$.1f MPG)",
        "th": "ซีดานขนาดเล็ก / อีโคคาร์ (%1$.1f MPG)"
    },
    "Full-Size SUV / Truck (%.1f MPG)": {
        "en": "Full-Size SUV / Truck (%1$.1f MPG)",
        "de": "Großer SUV / Pick-up (%1$.1f MPG)",
        "fr": "Grand SUV / Pick-up (%1$.1f MPG)",
        "es": "SUV grande / Camioneta (%1$.1f MPG)",
        "zh-Hans": "大型 SUV / 皮卡 (%1$.1f MPG)",
        "ja": "大型SUV / トラック (%1$.1f MPG)",
        "nb": "Stor SUV / Varebil (%1$.1f MPG)",
        "th": "SUV ขนาดใหญ่ / รถกระบะ (%1$.1f MPG)"
    },
    "TOTAL EXPENSE": {
        "en": "TOTAL EXPENSE",
        "de": "GESAMTAUSGABEN",
        "fr": "DÉPENSES TOTALES",
        "es": "GASTO TOTAL",
        "zh-Hans": "总支出",
        "ja": "総支出",
        "nb": "TOTALE UTGIFTER",
        "th": "ค่าใช้จ่ายทั้งหมด"
    },
    "TOTAL ENERGY": {
        "en": "TOTAL ENERGY",
        "de": "GESAMTENERGIE",
        "fr": "ÉNERGIE TOTALE",
        "es": "ENERGÍA TOTAL",
        "zh-Hans": "总电量",
        "ja": "総電力量",
        "nb": "TOTAL ENERGI",
        "th": "พลังงานทั้งหมด"
    },
    "HOME (OFF-PEAK)": {
        "en": "HOME (OFF-PEAK)",
        "de": "ZUHAUSE (NEBENZEIT)",
        "fr": "DOMICILE (HEURES CREUSES)",
        "es": "DOMICILIO (VALLE)",
        "zh-Hans": "家用 (谷段)",
        "ja": "自宅 (オフピーク)",
        "nb": "HJEMME (LAVPRIS)",
        "th": "ที่บ้าน (ช่วง Off-Peak)"
    },
    "PUBLIC FAST CHARGE": {
        "en": "PUBLIC FAST CHARGE",
        "de": "ÖFFENTLICHES SCHNELLLADEN",
        "fr": "CHARGE RAPIDE PUBLIQUE",
        "es": "CARGA RÁPIDA PÚBLICA",
        "zh-Hans": "公共快充",
        "ja": "公共急速充電",
        "nb": "OFFENTLIG HURTIGLADING",
        "th": "ชาร์จเร็วสาธารณะ"
    },
    "DATE & TIME": {
        "en": "DATE & TIME",
        "de": "DATUM & UHRZEIT",
        "fr": "DATE ET HEURE",
        "es": "FECHA Y HORA",
        "zh-Hans": "日期与时间",
        "ja": "日時",
        "nb": "DATO OG TID",
        "th": "วันและเวลา"
    },
    "LOCATION / VENDOR": {
        "en": "LOCATION / VENDOR",
        "de": "STANDORT / ANBIETER",
        "fr": "LIEU / FOURNISSEUR",
        "es": "UBICACIÓN / PROVEEDOR",
        "zh-Hans": "地点 / 运营商",
        "ja": "場所 / 事業者",
        "nb": "STED / LEVERANDØR",
        "th": "สถานที่ / ผู้ให้บริการ"
    },
    "TYPE": {
        "en": "TYPE",
        "de": "TYP",
        "fr": "TYPE",
        "es": "TIPO",
        "zh-Hans": "类型",
        "ja": "タイプ",
        "nb": "TYPE",
        "th": "ประเภท"
    },
    "ENERGY": {
        "en": "ENERGY",
        "de": "ENERGIE",
        "fr": "ÉNERGIE",
        "es": "ENERGÍA",
        "zh-Hans": "电量",
        "ja": "電力量",
        "nb": "ENERGI",
        "th": "พลังงาน"
    },
    "SoC": {
        "en": "SoC",
        "de": "SoC",
        "fr": "SoC",
        "es": "SoC",
        "zh-Hans": "电量 (SoC)",
        "ja": "SoC",
        "nb": "SoC",
        "th": "SoC"
    },
    "RATE": {
        "en": "RATE",
        "de": "TARIF",
        "fr": "TARIF",
        "es": "TARIFA",
        "zh-Hans": "单价",
        "ja": "単価",
        "nb": "PRIS",
        "th": "อัตราค่าไฟ"
    },
    "I certify that the electric vehicle charging expenses itemized above were incurred for vehicle operation and reflect actual electricity and charging fees paid.": {
        "en": "I certify that the electric vehicle charging expenses itemized above were incurred for vehicle operation and reflect actual electricity and charging fees paid.",
        "de": "Ich bestätige, dass die oben aufgeführten Ladekosten für den Betrieb des Fahrzeugs entstanden sind und die tatsächlich bezahlten Strom- und Ladegebühren widerspiegeln.",
        "fr": "Je certifie que les frais de recharge ci-dessus ont été engagés pour l'utilisation du véhicule et correspondent aux montants réels payés.",
        "es": "Certifico que los gastos de carga desglosados anteriormente se realizaron para el uso del vehículo y reflejan las tarifas reales pagadas.",
        "zh-Hans": "本人证明上述电动汽车充电费用系因车辆运行产生，并反映了实际支付的电费和充电服务费。",
        "ja": "上記の電気自動車充電費用は車両運行のために発生したものであり、実際に支払われた電気料金および充電料金であることを証明します。",
        "nb": "Jeg bekrefter at ladeutgiftene spesifisert ovenfor er påløpt for kjøretøyets drift og gjenspeiler faktiske betalte strøm- og ladegebyrer.",
        "th": "ข้าพเจ้าขอรับรองว่าค่าใช้จ่ายในการชาร์จรถยนต์ไฟฟ้าที่ระบุข้างต้นเกิดขึ้นจริงจากการใช้งานรถยนต์ และแสดงถึงค่าไฟฟ้าและค่าบริการชาร์จที่จ่ายจริง"
    },
    "Driver Signature / Date": {
        "en": "Driver Signature / Date",
        "de": "Unterschrift Fahrer / Datum",
        "fr": "Signature du conducteur / Date",
        "es": "Firma del conductor / Fecha",
        "zh-Hans": "驾驶员签名 / 日期",
        "ja": "ドライバー署名 / 日付",
        "nb": "Førers signatur / Dato",
        "th": "ลายมือชื่อผู้ขับขี่ / วันที่"
    },
    "Approved by / Date": {
        "en": "Approved by / Date",
        "de": "Genehmigt durch / Datum",
        "fr": "Approuvé par / Date",
        "es": "Aprobado por / Fecha",
        "zh-Hans": "审批人签名 / 日期",
        "ja": "承認者署名 / 日付",
        "nb": "Godkjent av / Dato",
        "th": "ผู้อนุมัติ / วันที่"
    },
    "EV Charging Expense & Reimbursement Statement": {
        "en": "EV Charging Expense & Reimbursement Statement",
        "de": "EV-Ladekostenabrechnung & Erstattungsnachweis",
        "fr": "Relevé des frais de recharge et remboursement VE",
        "es": "Informe de gastos y reembolso de carga de VE",
        "zh-Hans": "电动汽车充电费用报销对账单",
        "ja": "EV充電費用・立替精算明細書",
        "nb": "Ladeutgifts- og refusjonsoversikt for elbil",
        "th": "ใบสรุปค่าใช้จ่ายและเบิกจ่ายค่าชาร์จรถยนต์ไฟฟ้า"
    },
    "EV Charging Expense Statement - %@": {
        "en": "EV Charging Expense Statement - %1$@",
        "de": "EV-Ladekostenabrechnung - %1$@",
        "fr": "Relevé de recharge VE - %1$@",
        "es": "Informe de carga de VE - %1$@",
        "zh-Hans": "电动汽车充电费用对账单 - %1$@",
        "ja": "EV充電費用明細書 - %1$@",
        "nb": "Ladeoppgave for elbil - %1$@",
        "th": "ใบสรุปค่าใช้จ่ายการชาร์จ EV - %1$@"
    },
    "NMC / NCA: Keep Daily Charging to 80%–90%": {
        "en": "NMC / NCA: Keep Daily Charging to 80%–90%",
        "de": "NMC / NCA: Tägliches Laden auf 80%–90% begrenzen",
        "fr": "NMC / NCA : Limitez la charge quotidienne à 80 %–90 %",
        "es": "NMC / NCA: Mantenga la carga diaria al 80%–90%",
        "zh-Hans": "NMC / NCA: 日常充电上限保持在 80%–90%",
        "ja": "NMC / NCA: 日常の充電上限を80%〜90%に設定",
        "nb": "NMC / NCA: Hold daglig lading til 80 %–90 %",
        "th": "NMC / NCA: จำกัดการชาร์จประจำวันไว้ที่ 80%–90%"
    },
    "LFP: Charge to 100% Regularly for BMS Calibration": {
        "en": "LFP: Charge to 100% Regularly for BMS Calibration",
        "de": "LFP: Regelmäßig auf 100% laden zur BMS-Kalibrierung",
        "fr": "LFP : Chargez régulièrement à 100 % pour calibrer le BMS",
        "es": "LFP: Cargue al 100% regularmente para calibrar el BMS",
        "zh-Hans": "LFP: 定期充满至 100% 以校准 BMS",
        "ja": "LFP: BMS校正のため定期的に100%まで充電",
        "nb": "LFP: Lad regelmessig til 100 % for BMS-kalibrering",
        "th": "LFP: ชาร์จเต็ม 100% เป็นประจำเพื่อปรับเทียบ BMS"
    },
    "Prioritize AC Slow Charging for Daily Driving": {
        "en": "Prioritize AC Slow Charging for Daily Driving",
        "de": "AC-Langsamlader für den Alltag bevorzugen",
        "fr": "Privilégiez la recharge lente AC pour le quotidien",
        "es": "Priorice la carga lenta de CA para el uso diario",
        "zh-Hans": "日常行驶优先使用 AC 慢充",
        "ja": "日常の走行には普通充電（AC）を優先",
        "nb": "Prioriter AC-saktelading til daglig kjøring",
        "th": "ให้ความสำคัญกับการชาร์จช้า AC สำหรับการขับขี่ประจำวัน"
    },
    "Avoid Deep Discharges Below 10%–15%": {
        "en": "Avoid Deep Discharges Below 10%–15%",
        "de": "Tiefentladung unter 10%–15% vermeiden",
        "fr": "Évitez les décharges profondes sous 10 %–15 %",
        "es": "Evite descargas profundas por debajo del 10%–15%",
        "zh-Hans": "避免深度放电至 10%–15% 以下",
        "ja": "10%〜15%以下の深放電を避ける",
        "nb": "Unngå dyp utlading under 10 %–15 %",
        "th": "หลีกเลี่ยงการปล่อยให้แบตเตอรี่ลดต่ำกว่า 10%–15%"
    },
    "Precondition Battery Before DC Fast Charging": {
        "en": "Precondition Battery Before DC Fast Charging",
        "de": "Akku vor DC-Schnellladung vorkonditionieren",
        "fr": "Préconditionnez la batterie avant la charge rapide DC",
        "es": "Acondicione la batería antes de carga rápida en CC",
        "zh-Hans": "直流快充前预热/预冷电池",
        "ja": "急速充電（DC）前にバッテリーをプレコンディショニング",
        "nb": "Forvarm/kjøl batteriet før DC-hurtiglading",
        "th": "ปรับอุณหภูมิแบตเตอรี่ (Precondition) ก่อนชาร์จเร็ว DC"
    },
    "Store at 40%–60% SoC for Extended Inactivity": {
        "en": "Store at 40%–60% SoC for Extended Inactivity",
        "de": "Bei längerer Standzeit bei 40%–60% SoC lagern",
        "fr": "Stockez entre 40 % et 60 % de SoC lors d'une inactivité prolongée",
        "es": "Almacene al 40%–60% de SoC en periodos de inactividad",
        "zh-Hans": "长期停放时保持 40%–60% 电量",
        "ja": "長期間保管する場合はSoC 40%〜60%を維持",
        "nb": "Lagre ved 40 %–60 % SoC ved langvarig inaktivitet",
        "th": "รักษาระดับแบตเตอรี่ไว้ที่ 40%–60% เมื่อต้องจอดทิ้งไว้นาน"
    },
    "Daily Charge Limits": {
        "en": "Daily Charge Limits",
        "de": "Tägliche Ladelimits",
        "fr": "Limites de charge quotidienne",
        "es": "Límites de carga diaria",
        "zh-Hans": "日常充电上限",
        "ja": "日常の充電上限",
        "nb": "Daglige ladegrenser",
        "th": "ขีดจำกัดการชาร์จรายวัน"
    },
    "AC vs. DC Speed": {
        "en": "AC vs. DC Speed",
        "de": "AC- vs. DC-Geschwindigkeit",
        "fr": "Vitesse AC vs DC",
        "es": "Velocidad CA vs CC",
        "zh-Hans": "交流慢充 vs 直流快充",
        "ja": "普通充電（AC）と急速充電（DC）",
        "nb": "AC- vs. DC-hastighet",
        "th": "ความเร็ว AC เทียบกับ DC"
    },
    "Thermal Management": {
        "en": "Thermal Management",
        "de": "Thermisches Management",
        "fr": "Gestion thermique",
        "es": "Gestión térmica",
        "zh-Hans": "热管理",
        "ja": "温度管理",
        "nb": "Termisk styring",
        "th": "การจัดการอุณหภูมิ"
    },
    "Storage & Inactivity": {
        "en": "Storage & Inactivity",
        "de": "Lagerung & Standzeiten",
        "fr": "Stockage et inactivité",
        "es": "Almacenamiento e inactividad",
        "zh-Hans": "停放与存放",
        "ja": "保管と休止",
        "nb": "Lagring og inaktivitet",
        "th": "การจอดเก็บเป็นเวลานาน"
    },
    "All Chemistries": {
        "en": "All Chemistries",
        "de": "Alle Chemietypen",
        "fr": "Toutes les chimies",
        "es": "Todas las composiciones",
        "zh-Hans": "所有电池类型",
        "ja": "すべての化学種",
        "nb": "Alle kjemityper",
        "th": "แบตเตอรี่ทุกประเภท"
    },
    "LFP (Blade / Phosphate)": {
        "en": "LFP (Blade / Phosphate)",
        "de": "LFP (Blade / Phosphat)",
        "fr": "LFP (Blade / Phosphate)",
        "es": "LFP (Blade / Fosfato)",
        "zh-Hans": "LFP (刀片 / 磷酸铁锂)",
        "ja": "LFP (ブレード / リン酸鉄)",
        "nb": "LFP (Blade / Fosfat)",
        "th": "LFP (Blade / ฟอสเฟต)"
    },
    "NMC & NCA Chemistries": {
        "en": "NMC & NCA Chemistries",
        "de": "NMC- & NCA-Chemietypen",
        "fr": "Chimies NMC et NCA",
        "es": "Química NMC y NCA",
        "zh-Hans": "三元锂 (NMC / NCA)",
        "ja": "NMC & NCA 化学種",
        "nb": "NMC- og NCA-kjemier",
        "th": "แบตเตอรี่ NMC และ NCA"
    },
    "Nickel-rich chemistry undergoes accelerated cathode electrolyte oxidation and mechanical lattice strain when kept above 90% State of Charge.": {
        "en": "Nickel-rich chemistry undergoes accelerated cathode electrolyte oxidation and mechanical lattice strain when kept above 90% State of Charge.",
        "de": "Nickelreiche Akkus unterliegen bei über 90% SoC einer beschleunigten Kathodenoxidation und mechanischen Gitterspannungen.",
        "fr": "Les batteries riches en nickel subissent une oxydation accélérée et des tensions mécaniques lorsqu'elles sont maintenues au-dessus de 90 % de SoC.",
        "es": "Las baterías ricas en níquel sufren mayor oxidación y estrés mecánico cuando se mantienen por encima del 90% de carga.",
        "zh-Hans": "高镍三元电池在电量超过 90% 时会加速正极电解液氧化并造成晶格机械应变。",
        "ja": "高ニッケル系電池は90%以上のSoCで保持されると、正極酸化と格子歪みが加速します。",
        "nb": "Nikkelrike kjemier opplever akselerert oksidasjon og mekanisk spenning når de holdes over 90 % SoC.",
        "th": "แบตเตอรี่นิเกิลสูงจะเกิดปฏิกิริยาออกซิเดชันและความเค้นของผลึกสูงขึ้นอย่างมากเมื่อคงระดับไว้เกิน 90%"
    },
    "Lithium Iron Phosphate (LFP) has an exceptionally flat voltage curve between 20% and 90%, making voltage-based SoC estimation prone to drift without regular 100% top-offs.": {
        "en": "Lithium Iron Phosphate (LFP) has an exceptionally flat voltage curve between 20% and 90%, making voltage-based SoC estimation prone to drift without regular 100% top-offs.",
        "de": "Lithium-Eisenphosphat (LFP) besitzt eine sehr flache Spannungskurve zwischen 20% und 90%, weshalb das BMS regelmäßige 100%-Ladungen zur Kalibrierung benötigt.",
        "fr": "Le lithium-fer-phosphate (LFP) a une courbe de tension très plate entre 20 % et 90 %, ce qui rend l'estimation du SoC sujette à dérive sans recharge régulière à 100 %.",
        "es": "El fosfato de hierro y litio (LFP) tiene una curva de voltaje muy plana entre el 20% y el 90%, por lo que necesita cargas al 100% para calibrar el SoC.",
        "zh-Hans": "磷酸铁锂 (LFP) 在 20% 到 90% 之间的电压曲线极为平坦，若不定期充满至 100%，BMS 的电量估算容易产生偏差。",
        "ja": "リン酸鉄リチウム（LFP）は20%〜90%間の電圧曲線が極めて平坦なため、定期的に100%まで充電しないとSoC推定がずれる原因になります。",
        "nb": "Litium-jernfosfat (LFP) har en svært flat spenningskurve mellom 20 % og 90 %, noe som krever jevnlig 100 % lading for å unngå avvik i BMS-estimeringen.",
        "th": "แบตเตอรี่ลิเธียมไอรอนฟอสเฟต (LFP) มีกราฟแรงดันไฟฟ้าที่แบนราบมากระหว่าง 20% ถึง 90% ทำให้ระบบ BMS จำเป็นต้องชาร์จเต็ม 100% เป็นประจำเพื่อปรับเทียบค่าให้ตรง"
    },
    "Gentle AC charging (7–11 kW) minimizes internal cell heating, prevents lithium dendrite plating, and preserves the Solid Electrolyte Interphase (SEI) layer.": {
        "en": "Gentle AC charging (7–11 kW) minimizes internal cell heating, prevents lithium dendrite plating, and preserves the Solid Electrolyte Interphase (SEI) layer.",
        "de": "Schonendes AC-Laden (7–11 kW) minimiert die Zellwärme, verhindert Lithium-Dendritenbildung und schützt die SEI-Schicht.",
        "fr": "La charge lente AC (7 à 11 kW) minimise l'échauffement interne, prévient les dendrites de lithium et préserve la couche SEI.",
        "es": "La carga suave en CA (7–11 kW) minimiza el calentamiento celular, previene dendritas y conserva la capa SEI.",
        "zh-Hans": "温和的交流慢充 (7–11 kW) 可最大限度减少电芯内部发热，防止锂枝晶析出并保护 SEI 膜。",
        "ja": "穏やかな普通充電（7〜11 kW）はセル内部の発熱を抑え、リチウムデンドライトの析出を防ぎ、SEI被膜を保護します。",
        "nb": "Skånsom AC-lading (7–11 kW) minimerer intern oppvarming, forhindrer litiumdendritter og bevarer SEI-laget.",
        "th": "การชาร์จช้า AC (7–11 kW) ช่วยลดความร้อนภายในเซลล์ ป้องกันการเกิดลิเธียมเดนไดรต์ และถนอมชั้น SEI ได้อย่างดีเยี่ยม"
    },
    "Allowing lithium cells to drop below 10% increases internal resistance, generates copper dissolution risk on negative current collectors, and puts stress on individual weaker cells.": {
        "en": "Allowing lithium cells to drop below 10% increases internal resistance, generates copper dissolution risk on negative current collectors, and puts stress on individual weaker cells.",
        "de": "Fällt der Akkustand unter 10%, steigt der Innenwiderstand, Kupferauflösung am Anodenkollektor droht und schwächere Zellen werden übermäßig belastet.",
        "fr": "Laisser les cellules descendre sous 10 % augmente la résistance interne, risque la dissolution du cuivre et fatigue les cellules plus faibles.",
        "es": "Dejar que las celdas bajen del 10% aumenta la resistencia interna, arriesga disolución de cobre y estresa las celdas más débiles.",
        "zh-Hans": "电池电量低于 10% 会增加内阻，引发负极集流体铜溶解风险，并对单体弱芯造成严重应力。",
        "ja": "セルを10%未満に放電させると内部抵抗が増大し、銅の溶解リスクや個別セルの劣化を招きます。",
        "nb": "Å la cellene falle under 10 % øker den indre motstanden, skaper risiko for kobberoppløsning og belaster svakere celler.",
        "th": "การปล่อยให้แบตเตอรี่ลดต่ำกว่า 10% จะเพิ่มความต้านทานภายใน เสี่ยงต่อการละลายของทองแดงที่ขั้วลบ และสร้างความเค้นต่อเซลล์ที่อ่อนแอกว่า"
    },
    "Cold lithium cells have high internal resistance and cannot accept high charging currents safely, while overheated cells degrade rapidly.": {
        "en": "Cold lithium cells have high internal resistance and cannot accept high charging currents safely, while overheated cells degrade rapidly.",
        "de": "Kalte Lithiumzellen haben einen hohen Innenwiderstand und vertragen keine hohen Ladeströme, während überhitzte Zellen schnell degradieren.",
        "fr": "Les cellules froides ont une résistance interne élevée et ne peuvent accepter de forts courants sans danger, tandis que les cellules surchauffées se dégradent vite.",
        "es": "Las celdas frías tienen alta resistencia interna y no aceptan altas corrientes de forma segura, mientras que las recalentadas se degradan rápido.",
        "zh-Hans": "冰冷的锂电芯具有高内阻且无法安全承受大电流快充，而过热的电芯则会迅速发生化学衰退。",
        "ja": "低温のリチウムセルは内部抵抗が高く高出力を安全に受け入れられず、過熱したセルは急速に劣化します。",
        "nb": "Kalde litiumceller har høy indre motstand og tåler ikke høye ladestrømmer, mens overopphetede celler forringes raskt.",
        "th": "เซลล์ลิเธียมที่เย็นจัดจะมีความต้านทานภายในสูงและรับกระแสชาร์จแรงไม่ได้ ในขณะที่เซลล์ที่ร้อนเกินไปจะเสื่อมสภาพอย่างรวดเร็ว"
    },
    "Storing an EV battery at extreme charge levels (0% or 100%) for weeks accelerates calendar degradation and irreversible capacity loss.": {
        "en": "Storing an EV battery at extreme charge levels (0% or 100%) for weeks accelerates calendar degradation and irreversible capacity loss.",
        "de": "Wird ein E-Auto-Akku über Wochen bei Extremwerten (0% oder 100%) gelagert, beschleunigt dies die kalendarische Alterung und irreversible Kapazitätsverluste.",
        "fr": "Stocker une batterie de VE à des niveaux extrêmes (0 % ou 100 %) pendant des semaines accélère la dégradation calendaire et la perte irréversible.",
        "es": "Guardar una batería de VE en niveles extremos (0% o 100%) durante semanas acelera la degradación y la pérdida irreversible.",
        "zh-Hans": "将电动汽车电池在极端电量（0% 或 100%）下停放数周会加速日历老化并造成不可逆的容量损失。",
        "ja": "極端な充電レベル（0%または100%）で長期間放置すると、カレンダー劣化と不可逆的な容量低下が加速します。",
        "nb": "Lagring av et elbilbatteri ved ekstreme nivåer (0 % eller 100 %) i uker fremskynder kalenderaldring og irreversibelt kapasitetstap.",
        "th": "การจอดรถ EV ทิ้งไว้ที่ระดับแบตเตอรี่สุดโต่ง (0% หรือ 100%) เป็นเวลาหลายสัปดาห์ จะเร่งการเสื่อมสภาพตามเวลาและการสูญเสียความจุถาวร"
    },
    "Set your vehicle's charge limit slider to 80% (or 90% maximum) for daily commutes.": {
        "en": "Set your vehicle's charge limit slider to 80% (or 90% maximum) for daily commutes.",
        "de": "Stellen Sie das Ladelimit im Fahrzeug für den Alltag auf 80% (maximal 90%) ein.",
        "fr": "Réglez la limite de charge de votre véhicule à 80 % (ou 90 % max) pour les trajets quotidiens.",
        "es": "Configure el límite de carga de su vehículo al 80% (o 90% máximo) para el día a día.",
        "zh-Hans": "日常通勤请将车辆充电限制滑块设置为 80%（最高不超过 90%）。",
        "ja": "日常の走行では、車両の充電上限スライダーを80%（最大でも90%）に設定してください。",
        "nb": "Still inn ladegrensen i bilen til 80 % (maks 90 %) for daglig pendling.",
        "th": "ตั้งค่าขีดจำกัดการชาร์จในรถยนต์ไว้ที่ 80% (หรือไม่เกิน 90%) สำหรับการใช้งานประจำวัน"
    },
    "Charge to 100% only just before departing on long road trips.": {
        "en": "Charge to 100% only just before departing on long road trips.",
        "de": "Laden Sie nur unmittelbar vor längeren Fahrten auf 100%.",
        "fr": "Ne chargez à 100 % que juste avant de partir pour de longs trajets.",
        "es": "Cargue al 100% solo justo antes de salir en viajes largos.",
        "zh-Hans": "仅在长途出行出发前才充至 100%。",
        "ja": "100%までの満充電は、長距離ドライブの出発直前のみに限定してください。",
        "nb": "Lad til 100 % kun rett før avreise på lengre turer.",
        "th": "ชาร์จเต็ม 100% เฉพาะก่อนออกเดินทางไกลทันทีเท่านั้น"
    },
    "Avoid letting the car sit parked at 100% for days, especially in warm weather.": {
        "en": "Avoid letting the car sit parked at 100% for days, especially in warm weather.",
        "de": "Vermeiden Sie es, das Auto tagelang bei 100% stehen zu lassen, besonders bei warmem Wetter.",
        "fr": "Évitez de laisser le véhicule stationné à 100 % pendant plusieurs jours, surtout par temps chaud.",
        "es": "Evite dejar el coche estacionado al 100% durante días, especialmente con calor.",
        "zh-Hans": "避免让车辆在 100% 满电状态下停放数天，尤其是在炎热天气下。",
        "ja": "特に暑い時期に、100%の状態で何日も放置することは避けてください。",
        "nb": "Unngå å la bilen stå parkert med 100 % i flere dager, særlig i varmt vær.",
        "th": "หลีกเลี่ยงการจอดรถทิ้งไว้ที่ 100% เป็นเวลาหลายวัน โดยเฉพาะในสภาพอากาศร้อน"
    },
    "Charge your LFP vehicle to 100% at least once every 1 to 2 weeks.": {
        "en": "Charge your LFP vehicle to 100% at least once every 1 to 2 weeks.",
        "de": "Laden Sie Ihr LFP-Fahrzeug mindestens alle 1 bis 2 Wochen auf 100%.",
        "fr": "Chargez votre véhicule LFP à 100 % au moins une fois toutes les 1 à 2 semaines.",
        "es": "Cargue su vehículo LFP al 100% al menos una vez cada 1 o 2 semanas.",
        "zh-Hans": "建议每 1 至 2 周至少将 LFP 车辆充满至 100% 一次。",
        "ja": "LFPバッテリー搭載車は、1〜2週間に1回以上100%まで充電してください。",
        "nb": "Lad LFP-bilen til 100 % minst én gang hver 1. til 2. uke.",
        "th": "ชาร์จรถยนต์ LFP ให้เต็ม 100% อย่างน้อยทุกๆ 1 ถึง 2 สัปดาห์"
    },
    "Charging to 100% allows the Battery Management System (BMS) to perform passive cell balancing.": {
        "en": "Charging to 100% allows the Battery Management System (BMS) to perform passive cell balancing.",
        "de": "Das Laden auf 100% ermöglicht dem BMS das passive Ausbalancieren der einzelnen Zellen.",
        "fr": "La charge à 100 % permet au BMS d'effectuer l'équilibrage passif des cellules.",
        "es": "Cargar al 100% permite al BMS realizar el equilibrado pasivo de celdas.",
        "zh-Hans": "充至 100% 可以让电池管理系统 (BMS) 执行单体电芯被动均衡。",
        "ja": "100%まで充電することで、BMSが個別セルの電圧バランシングを実行できます。",
        "nb": "Lading til 100 % gjør at BMS kan utføre passiv cellebalansering.",
        "th": "การชาร์จถึง 100% ช่วยให้ระบบ BMS สามารถปรับสมดุลแรงดันไฟฟ้าของแต่ละเซลล์ได้อย่างสมบูรณ์"
    },
    "LFP has superior thermal stability and suffers far less degradation from full charges compared to NMC.": {
        "en": "LFP has superior thermal stability and suffers far less degradation from full charges compared to NMC.",
        "de": "LFP weist eine höhere thermische Stabilität auf und degradiert bei Vollladung deutlich weniger als NMC.",
        "fr": "Le LFP possède une stabilité thermique supérieure et souffre bien moins des charges complètes que le NMC.",
        "es": "LFP tiene mayor estabilidad térmica y sufre mucha menos degradación al cargarse al 100% en comparación con NMC.",
        "zh-Hans": "LFP 具有极高的热稳定性，相比三元锂电池，满电充电带来的衰减要小得多。",
        "ja": "LFPは熱安定性に優れており、NMCと比較して満充電による劣化が極めて少ない特徴があります。",
        "nb": "LFP har overlegen termisk stabilitet og tar langt mindre skade av fullading sammenlignet med NMC.",
        "th": "แบตเตอรี่ LFP มีความเสถียรทางความร้อนสูง และเกิดการเสื่อมสภาพจากการชาร์จเต็ม 100% น้อยกว่า NMC มาก"
    },
    "Rely on Home or Work AC chargers for >= 70% of your total energy intake.": {
        "en": "Rely on Home or Work AC chargers for >= 70% of your total energy intake.",
        "de": "Nutzen Sie für >= 70% Ihres Energiebedarfs AC-Lader zu Hause oder am Arbeitsplatz.",
        "fr": "Privilégiez la recharge AC à domicile ou au travail pour au moins 70 % de votre énergie totale.",
        "es": "Utilice cargadores de CA en casa o trabajo para >= 70% de su energía total.",
        "zh-Hans": "建议总电量的 70% 以上通过家用或公司交流慢充获取。",
        "ja": "総充電電力量の70%以上を自宅や職場の普通充電（AC）で賄うことをお勧めします。",
        "nb": "Bruk AC-lading hjemme eller på jobb for minst 70 % av det totale energiforbruket.",
        "th": "ควรใช้ที่ชาร์จ AC ที่บ้านหรือที่ทำงานสำหรับพลังงานอย่างน้อย 70% ของการใช้งานทั้งหมด"
    },
    "Reserve high-power DC Fast Chargers (50–350 kW) for long road trips where quick turnaround is essential.": {
        "en": "Reserve high-power DC Fast Chargers (50–350 kW) for long road trips where quick turnaround is essential.",
        "de": "Reservieren Sie DC-Schnelllader (50–350 kW) für lange Fahrten, bei denen kurze Ladezeiten nötig sind.",
        "fr": "Réservez les chargeurs rapides DC (50–350 kW) aux longs voyages nécessitant des arrêts courts.",
        "es": "Reserve los cargadores rápidos de CC (50–350 kW) para viajes largos donde se requiera rapidez.",
        "zh-Hans": "将高功率直流快充 (50–350 kW) 留给需要快速补能的长途旅行使用。",
        "ja": "高出力急速充電器（50〜350 kW）は、長距離移動時の素早い補給に限定してください。",
        "nb": "Reserver DC-hurtigladere (50–350 kW) for langkjøring der rask lading er avgjørende.",
        "th": "เก็บตู้ชาร์จเร็ว DC กำลังสูง (50–350 kW) ไว้ใช้สำหรับการเดินทางไกลที่ต้องการความสะดวกรวดเร็ว"
    },
    "Whenever possible, avoid consecutive DC rapid charges in high ambient heat without cool-down intervals.": {
        "en": "Whenever possible, avoid consecutive DC rapid charges in high ambient heat without cool-down intervals.",
        "de": "Vermeiden Sie nach Möglichkeit aufeinanderfolgende DC-Schnellladungen bei großer Hitze ohne Abkühlpause.",
        "fr": "Évitez autant que possible les recharges rapides DC consécutives par forte chaleur sans temps de refroidissement.",
        "es": "Evite cargas rápidas consecutivas en CC con calor extremo sin pausas de enfriamiento.",
        "zh-Hans": "在高温天气下尽量避免在没有冷却间隔的情况下连续进行多次直流快充。",
        "ja": "高温環境下で冷却時間を置かずに連続して急速充電を行うことは極力避けてください。",
        "nb": "Unngå om mulig gjentatte DC-hurtigladinger i høy varme uten nedkjølingspauser.",
        "th": "หลีกเลี่ยงการชาร์จเร็ว DC ต่อเนื่องหลายครั้งติดกันในสภาพอากาศร้อนจัดโดยไม่มีช่วงพักระบายความร้อน"
    },
    "Plug in when your battery reaches 15%–20% during normal day-to-day driving.": {
        "en": "Plug in when your battery reaches 15%–20% during normal day-to-day driving.",
        "de": "Stecken Sie das Auto im Alltag an, sobald der Akku 15%–20% erreicht.",
        "fr": "Branchez le véhicule lorsque la batterie atteint 15 %–20 % au quotidien.",
        "es": "Enchufe el vehículo cuando la batería alcance el 15%–20% en el día a día.",
        "zh-Hans": "日常行驶中，当电量降至 15%–20% 时即可插枪充电。",
        "ja": "日常の走行では、バッテリー残量が15%〜20%になったら充電プラグを接続してください。",
        "nb": "Koble til laderen når batteriet når 15 %–20 % ved vanlig dagligkjøring.",
        "th": "เสียบชาร์จเมื่อแบตเตอรี่ลดลงเหลือ 15%–20% ในการใช้งานประจำวันทั่วไป"
    },
    "Never leave your vehicle parked at < 5% State of Charge for extended hours.": {
        "en": "Never leave your vehicle parked at < 5% State of Charge for extended hours.",
        "de": "Lassen Sie das Fahrzeug niemals über längere Zeit mit < 5% SoC stehen.",
        "fr": "Ne laissez jamais le véhicule stationné à moins de 5 % de SoC pendant de longues heures.",
        "es": "Nunca deje el vehículo estacionado con < 5% de SoC durante horas prolongadas.",
        "zh-Hans": "切勿将车辆在低于 5% 的极低电量状态下长时间停放。",
        "ja": "残量が5%未満の状態で車を何時間も放置しないでください。",
        "nb": "La aldri bilen stå parkert med under 5 % SoC i lengre perioder.",
        "th": "ห้ามจอดรถทิ้งไว้ที่ระดับแบตเตอรี่ต่ำกว่า 5% เป็นเวลานานหลายชั่วโมงโดยเด็ดขาด"
    },
    "If running very low in cold conditions, charge immediately while the pack is still warm from driving.": {
        "en": "If running very low in cold conditions, charge immediately while the pack is still warm from driving.",
        "de": "Laden Sie bei Kälte und niedrigem Akkustand sofort, solange der Akku noch von der Fahrt warm ist.",
        "fr": "Par temps froid et batterie faible, chargez immédiatement tant que la batterie est encore chaude.",
        "es": "Con frío y poca batería, cargue inmediatamente mientras el pack siga caliente del viaje.",
        "zh-Hans": "如果在寒冷天气下电量过低，请趁刚行驶完电池尚有余温时立即充电。",
        "ja": "寒冷地で残量が少ない場合は、走行直後のバッテリーが温かいうちにすぐ充電してください。",
        "nb": "Hvis batteriet er lavt i kulde, lad umiddelbart mens batteripakken fortsatt er varm etter kjøring.",
        "th": "หากแบตเตอรี่เหลือน้อยในสภาพอากาศเย็น ควรรีบเสียบชาร์จทันทีขณะที่แบตเตอรี่ยังอุ่นจากการขับขี่"
    },
    "Use built-in vehicle navigation to navigate to fast chargers so the BMS automatically pre-heats/cools the pack.": {
        "en": "Use built-in vehicle navigation to navigate to fast chargers so the BMS automatically pre-heats/cools the pack.",
        "de": "Nutzen Sie das bordeigene Navi zur Ladesäule, damit das BMS den Akku rechtzeitig temperiert.",
        "fr": "Utilisez le GPS intégré pour aller aux bornes rapides afin que le BMS préconditionne la batterie.",
        "es": "Use el navegador integrado para ir a cargadores rápidos y preacondicionar la batería.",
        "zh-Hans": "使用车载原厂导航前往快充站，以便 BMS 自动提前预热/预冷电池组。",
        "ja": "車載ナビで充電スタンドを設定し、BMSが自動で温度調節できるようにしてください。",
        "nb": "Bruk bilens integrerte navigasjon til hurtigladere slik at BMS automatisk tempererer batteriet.",
        "th": "ใช้ระบบนำทางในรถนำทางไปยังตู้ชาร์จเร็ว เพื่อให้ระบบ BMS ปรับอุณหภูมิแบตเตอรี่ล่วงหน้าโดยอัตโนมัติ"
    },
    "Avoid aggressive DC fast charging immediately after leaving the car in freezing temperatures.": {
        "en": "Avoid aggressive DC fast charging immediately after leaving the car in freezing temperatures.",
        "de": "Vermeiden Sie maximale DC-Schnellladung direkt nach dem Start bei Minusgraden.",
        "fr": "Évitez la charge rapide DC intense immédiatement après un stationnement par grand froid.",
        "es": "Evite cargas rápidas agresivas inmediatamente después de dejar el coche bajo cero.",
        "zh-Hans": "避免在车辆长时间处于严寒环境后立即进行大功率直流快充。",
        "ja": "氷点下で放置した直後に強力な急速充電を行うことは避けてください。",
        "nb": "Unngå kraftig DC-hurtiglading rett etter at bilen har stått i minusgrader.",
        "th": "หลีกเลี่ยงการชาร์จเร็ว DC ทันทีหลังจากจอดรถตากอากาศเย็นจัดเป็นเวลานาน"
    },
    "In hot climates, try to charge in shaded areas or covered parking garages when feasible.": {
        "en": "In hot climates, try to charge in shaded areas or covered parking garages when feasible.",
        "de": "In heißen Regionen möglichst im Schatten oder in überdachten Parkhäusern laden.",
        "fr": "Par climat chaud, essayez de recharger à l'ombre ou dans un parking couvert.",
        "es": "En climas cálidos, intente cargar en la sombra o en garajes cubiertos.",
        "zh-Hans": "在炎热气候下，尽量选择在阴凉处或有遮挡的室内停车场进行充电。",
        "ja": "暑い地域では、日陰や屋根付きの駐車場で充電することをお勧めします。",
        "nb": "I varmt klima, prøv å lade i skyggen eller i parkeringshus.",
        "th": "ในสภาพอากาศร้อนจัด ควรเลือกชาร์จในที่ร่มหรืออาคารจอดรถที่มีหลังคาบังแดด"
    },
    "If leaving your car unused for more than 2 weeks, set SoC to approximately 50%.": {
        "en": "If leaving your car unused for more than 2 weeks, set SoC to approximately 50%.",
        "de": "Wenn das Auto länger als 2 Wochen steht, stellen Sie den SoC auf etwa 50% ein.",
        "fr": "Si vous n'utilisez pas votre voiture pendant plus de 2 semaines, réglez le SoC à environ 50 %.",
        "es": "Si no usará el coche más de 2 semanas, ajuste el SoC al 50% aproximadamente.",
        "zh-Hans": "若车辆停放不用超过 2 周，请将电量调整至 50% 左右。",
        "ja": "2週間以上使用しない場合は、SoCを約50%に設定してください。",
        "nb": "Hvis bilen ikke skal brukes på over 2 uker, sett SoC til omtrent 50 %.",
        "th": "หากไม่ได้ใช้งานรถนานเกิน 2 สัปดาห์ ให้รักษาระดับแบตเตอรี่ไว้ที่ประมาณ 50%"
    },
    "Keep the vehicle plugged into a slow charger with the target set to 50% so auxiliary systems don't drain the 12V battery.": {
        "en": "Keep the vehicle plugged into a slow charger with the target set to 50% so auxiliary systems don't drain the 12V battery.",
        "de": "Lassen Sie das Auto mit 50%-Limit am Lader, damit Hilfssysteme die 12V-Batterie nicht entleeren.",
        "fr": "Laissez le véhicule branché à 50 % pour éviter que les systèmes auxiliaires ne vident la batterie 12 V.",
        "es": "Deje el coche conectado a un cargador lento al 50% para proteger la batería de 12 V.",
        "zh-Hans": "将车辆连接到慢充桩并将目标设为 50%，以防止辅助系统耗尽 12V 小电瓶。",
        "ja": "50%目標で普通充電器に接続しておくと、補機用12Vバッテリーの放電も防げます。",
        "nb": "Hold bilen tilkoblet en saktelader satt til 50 % slik at 12V-batteriet ikke tappes.",
        "th": "เสียบชาร์จช้าทิ้งไว้โดยตั้งเป้าหมายที่ 50% เพื่อป้องกันไม่ให้ระบบเสริมดึงไฟจากแบตเตอรี่ 12V จนหมด"
    },
    "Store in a temperature-moderate garage if possible to avoid extreme seasonal thermal extremes.": {
        "en": "Store in a temperature-moderate garage if possible to avoid extreme seasonal thermal extremes.",
        "de": "Möglichst in einer temperaturgeschützten Garage parken, um extreme Temperaturen zu meiden.",
        "fr": "Stationnez dans un garage tempéré si possible pour éviter les écarts thermiques extrêmes.",
        "es": "Guarde en un garaje con temperatura moderada para evitar extremos estacionales.",
        "zh-Hans": "尽可能停放在温度适宜的室内车库中，以避免季节性极端气温。",
        "ja": "極端な気温変化を避けるため、可能であれば温度管理されたガレージに保管してください。",
        "nb": "Lagre om mulig i en temperaturregulert garasje for å unngå sesongmessige ytterpunkter.",
        "th": "จอดในโรงรถที่มีอุณหภูมิปานกลางหากทำได้ เพื่อหลีกเลี่ยงสภาพอากาศที่ร้อนหรือหนาวจัดตามฤดูกาล"
    },
    "My Vehicle": {
        "en": "My Vehicle",
        "de": "Mein Fahrzeug",
        "fr": "Mon véhicule",
        "es": "Mi vehículo",
        "zh-Hans": "当前车辆",
        "ja": "マイカー",
        "nb": "Mitt kjøretøy",
        "th": "รถของฉัน"
    },
    "All Guides": {
        "en": "All Guides",
        "de": "Alle Leitfäden",
        "fr": "Tous les guides",
        "es": "Todas las guías",
        "zh-Hans": "所有指南",
        "ja": "すべてのガイド",
        "nb": "Alle veiledninger",
        "th": "คู่มือทั้งหมด"
    },
    "Optimal Habits (A+)": {
        "en": "Optimal Habits (A+)",
        "de": "Optimale Gewohnheiten (A+)",
        "fr": "Habitudes optimales (A+)",
        "es": "Hábitos óptimos (A+)",
        "zh-Hans": "极佳习惯 (A+)",
        "ja": "最適な充電習慣 (A+)",
        "nb": "Optimale vaner (A+)",
        "th": "พฤติกรรมดีเยี่ยม (A+)"
    },
    "Great Habits (A)": {
        "en": "Great Habits (A)",
        "de": "Hervorragende Gewohnheiten (A)",
        "fr": "Excellentes habitudes (A)",
        "es": "Grandes hábitos (A)",
        "zh-Hans": "优秀习惯 (A)",
        "ja": "優れた充電習慣 (A)",
        "nb": "Flotte vaner (A)",
        "th": "พฤติกรรมดีมาก (A)"
    },
    "Good Habits (B)": {
        "en": "Good Habits (B)",
        "de": "Gute Gewohnheiten (B)",
        "fr": "Bonnes habitudes (B)",
        "es": "Buenos hábitos (B)",
        "zh-Hans": "良好习惯 (B)",
        "ja": "良好な充電習慣 (B)",
        "nb": "Gode vaner (B)",
        "th": "พฤติกรรมดี (B)"
    },
    "Moderate Stress (C)": {
        "en": "Moderate Stress (C)",
        "de": "Mäßige Belastung (C)",
        "fr": "Stress modéré (C)",
        "es": "Estrés moderado (C)",
        "zh-Hans": "中度损耗习惯 (C)",
        "ja": "中程度の負荷 (C)",
        "nb": "Moderat belastning (C)",
        "th": "ภาระปานกลาง (C)"
    },
    "High Wear Habits (D)": {
        "en": "High Wear Habits (D)",
        "de": "Hohe Abnutzung (D)",
        "fr": "Habitudes à forte usure (D)",
        "es": "Hábitos de alto desgaste (D)",
        "zh-Hans": "高损耗习惯 (D)",
        "ja": "高い負荷の習慣 (D)",
        "nb": "Høy slitasje (D)",
        "th": "พฤติกรรมเสื่อมไว (D)"
    },
    "Optimal for Longevity": {
        "en": "Optimal for Longevity",
        "de": "Optimal für Langlebigkeit",
        "fr": "Optimal pour la longévité",
        "es": "Óptimo para la longevidad",
        "zh-Hans": "极利于电池寿命",
        "ja": "長寿命に最適",
        "nb": "Optimalt for levetid",
        "th": "ถนอมแบตเตอรี่สูงสุด"
    },
    "Good Condition Routine": {
        "en": "Good Condition Routine",
        "de": "Guter Erhaltungszustand",
        "fr": "Bonne routine de préservation",
        "es": "Buena rutina de conservación",
        "zh-Hans": "良好的保养状态",
        "ja": "良好な維持ルーチン",
        "nb": "God bevaringsrutine",
        "th": "อยู่ในเกณฑ์ดีถนอมแบต"
    },
    "Moderate Thermal / Cycle Stress": {
        "en": "Moderate Thermal / Cycle Stress",
        "de": "Mäßige thermische / zyklische Belastung",
        "fr": "Stress thermique et cyclique modéré",
        "es": "Estrés térmico y de ciclo moderado",
        "zh-Hans": "中度热应力与循环损耗",
        "ja": "中程度の熱・サイクル負荷",
        "nb": "Moderat termisk/syklisk stress",
        "th": "มีความร้อนหรือความเค้นปานกลาง"
    },
    "Elevated Battery Degradation Risk": {
        "en": "Elevated Battery Degradation Risk",
        "de": "Erhöhtes Degradationsrisiko",
        "fr": "Risque accru de dégradation",
        "es": "Riesgo elevado de degradación",
        "zh-Hans": "电池加速衰减风险偏高",
        "ja": "劣化リスクが高い状態",
        "nb": "Forhøyet degraderingsrisiko",
        "th": "เสี่ยงต่อการเสื่อมสภาพเร็ว"
    },
    "Start Logging Sessions": {
        "en": "Start Logging Sessions",
        "de": "Ladevorgänge erfassen",
        "fr": "Commencez à enregistrer des sessions",
        "es": "Comience a registrar sesiones",
        "zh-Hans": "开始记录充电",
        "ja": "セッションの記録を開始",
        "nb": "Start loggføring av ladeøkter",
        "th": "เริ่มบันทึกการชาร์จ"
    },
    "Excellent AC / DC Ratio": {
        "en": "Excellent AC / DC Ratio",
        "de": "Ausgezeichnetes AC/DC-Verhältnis",
        "fr": "Excellent ratio AC / DC",
        "es": "Excelente proporción CA / CC",
        "zh-Hans": "出色的慢充与快充比例",
        "ja": "優れたAC/DC比率",
        "nb": "Utmerket AC/DC-forhold",
        "th": "สัดส่วน AC/DC ยอดเยี่ยม"
    },
    "High DC Fast Charging Frequency": {
        "en": "High DC Fast Charging Frequency",
        "de": "Hohe DC-Schnellladehäufigkeit",
        "fr": "Fréquence élevée de charge rapide DC",
        "es": "Alta frecuencia de carga rápida en CC",
        "zh-Hans": "直流快充频率较高",
        "ja": "急速充電（DC）の頻度が高い",
        "nb": "Høy frekvens av DC-hurtiglading",
        "th": "ใช้การชาร์จเร็ว DC บ่อยครั้ง"
    },
    "Balanced Charging Speeds": {
        "en": "Balanced Charging Speeds",
        "de": "Ausgewogene Ladegeschwindigkeiten",
        "fr": "Vitesses de charge équilibrées",
        "es": "Velocidades de carga equilibradas",
        "zh-Hans": "均衡的充电速度组合",
        "ja": "バランスの取れた充電速度",
        "nb": "Balanserte ladehastigheter",
        "th": "ความเร็วการชาร์จมีความสมดุล"
    },
    "BMS Well Calibrated (100% LFP Routine)": {
        "en": "BMS Well Calibrated (100% LFP Routine)",
        "de": "BMS gut kalibriert (100% LFP-Routine)",
        "fr": "BMS bien calibré (Routine 100 % LFP)",
        "es": "BMS bien calibrado (Rutina 100% LFP)",
        "zh-Hans": "BMS 校准良好 (LFP 定期充满)",
        "ja": "BMS校正良好（LFP 100%ルーチン）",
        "nb": "BMS godt kalibrert (100 % LFP-rutine)",
        "th": "BMS ปรับเทียบสมบูรณ์ (ชาร์จ LFP 100% สม่ำเสมอ)"
    },
    "100% LFP Top-Off Recommended": {
        "en": "100% LFP Top-Off Recommended",
        "de": "100% LFP-Vollladung empfohlen",
        "fr": "Recharge à 100 % recommandée (LFP)",
        "es": "Recarga al 100% recomendada (LFP)",
        "zh-Hans": "建议进行一次 LFP 100% 充满校准",
        "ja": "LFP 100%充電をお勧めします",
        "nb": "100 % LFP-topplading anbefales",
        "th": "แนะนำให้ชาร์จ LFP เต็ม 100% เพื่อปรับเทียบ"
    },
    "Schedule Periodic 100% Charge": {
        "en": "Schedule Periodic 100% Charge",
        "de": "Regelmäßige 100%-Ladung einplanen",
        "fr": "Planifiez une charge périodique à 100 %",
        "es": "Programe una carga periódica al 100%",
        "zh-Hans": "安排定期的 100% 充电",
        "ja": "定期的な100%充電を計画してください",
        "nb": "Planlegg periodisk 100 % lading",
        "th": "วางแผนชาร์จเต็ม 100% เป็นระยะ"
    },
    "Regular 100% LFP Calibration": {
        "en": "Regular 100% LFP Calibration",
        "de": "Regelmäßige 100% LFP-Kalibrierung",
        "fr": "Calibration régulière à 100 % LFP",
        "es": "Calibración regular al 100% LFP",
        "zh-Hans": "定期进行 LFP 满电校准",
        "ja": "定期的なLFP 100%校正",
        "nb": "Jevnlig 100 % LFP-kalibrering",
        "th": "ปรับเทียบ LFP 100% สม่ำเสมอ"
    },
    "Calibrate LFP Battery to 100%": {
        "en": "Calibrate LFP Battery to 100%",
        "de": "LFP-Akku auf 100% kalibrieren",
        "fr": "Calibrez la batterie LFP à 100 %",
        "es": "Calibre la batería LFP al 100%",
        "zh-Hans": "将 LFP 电池充至 100% 进行校准",
        "ja": "LFPバッテリーを100%まで充電して校正",
        "nb": "Kalibrer LFP-batteriet til 100 %",
        "th": "ปรับเทียบแบตเตอรี่ LFP ที่ 100%"
    },
    "Lower Daily Limit to 80%–90%": {
        "en": "Lower Daily Limit to 80%–90%",
        "de": "Tägliches Limit auf 80%–90% senken",
        "fr": "Baissez la limite quotidienne à 80 %–90 %",
        "es": "Reduzca el límite diario al 80%–90%",
        "zh-Hans": "将日常充电上限降至 80%–90%",
        "ja": "日常上限を80%〜90%に下げる",
        "nb": "Senk daglig grense til 80 %–90 %",
        "th": "ลดขีดจำกัดประจำวันลงเหลือ 80%–90%"
    },
    "Healthy Daily SoC Limit": {
        "en": "Healthy Daily SoC Limit",
        "de": "Gesundes tägliches SoC-Limit",
        "fr": "Limite quotidienne de SoC saine",
        "es": "Límite diario de SoC saludable",
        "zh-Hans": "健康的日常充电上限",
        "ja": "健康的な日常SoC上限設定",
        "nb": "Sunn daglig SoC-grense",
        "th": "การตั้งขีดจำกัด SoC รายวันอย่างเหมาะสม"
    },
    "Avoid Deep Discharges Below 10%": {
        "en": "Avoid Deep Discharges Below 10%",
        "de": "Tiefentladung unter 10% vermeiden",
        "fr": "Évitez les décharges sous 10 %",
        "es": "Evite descargas por debajo del 10%",
        "zh-Hans": "避免深度放电至 10% 以下",
        "ja": "10%未満への深放電を避ける",
        "nb": "Unngå utlading under 10 %",
        "th": "หลีกเลี่ยงการปล่อยให้แบตลดต่ำกว่า 10%"
    },
    "Plug In Earlier for Better Buffer": {
        "en": "Plug In Earlier for Better Buffer",
        "de": "Früher anstecken für mehr Puffer",
        "fr": "Branchez plus tôt pour une meilleure marge",
        "es": "Enchufe antes para mayor margen",
        "zh-Hans": "提早充电以留出安全余量",
        "ja": "余裕を持って早めに充電",
        "nb": "Koble til tidligere for bedre buffer",
        "th": "เสียบชาร์จให้เร็วขึ้นเพื่อรักษาระดับสำรอง"
    },
    "Healthy Lower SoC Buffer": {
        "en": "Healthy Lower SoC Buffer",
        "de": "Gesunder unterer SoC-Puffer",
        "fr": "Bonne marge inférieure de SoC",
        "es": "Buen margen inferior de SoC",
        "zh-Hans": "良好的低电量保护余量",
        "ja": "適切な低残量バッファ",
        "nb": "Sunn nedre SoC-buffer",
        "th": "มีระยะสำรองแบตเตอรี่ช่วงต่ำที่ดี"
    },
    "Log charging sessions to analyze your charging habits and receive personalized battery longevity recommendations.": {
        "en": "Log charging sessions to analyze your charging habits and receive personalized battery longevity recommendations.",
        "de": "Erfassen Sie Ladevorgänge, um Ihre Gewohnheiten zu analysieren und individuelle Empfehlungen zu erhalten.",
        "fr": "Enregistrez vos sessions de recharge pour analyser vos habitudes et obtenir des conseils personnalisés.",
        "es": "Registre sesiones de carga para analizar sus hábitos y recibir recomendaciones personalizadas.",
        "zh-Hans": "记录充电数据以分析您的充电习惯并获取个性化的电池养护建议。",
        "ja": "充電セッションを記録して習慣を分析し、パーソナライズされた長寿命化アドバイスを受け取りましょう。",
        "nb": "Loggfør ladeøkter for å analysere vanene dine og få tilpassede råd for batterihelse.",
        "th": "บันทึกการชาร์จเพื่อวิเคราะห์พฤติกรรมและรับคำแนะนำในการถนอมแบตเตอรี่เฉพาะสำหรับคุณ"
    },
    "Your charging behavior is exceptionally gentle on your battery pack.": {
        "en": "Your charging behavior is exceptionally gentle on your battery pack.",
        "de": "Ihr Ladeverhalten schont den Akku Ihres Fahrzeugs in hervorragender Weise.",
        "fr": "Votre comportement de recharge est particulièrement respectueux de votre batterie.",
        "es": "Su comportamiento de carga es excepcionalmente suave con su batería.",
        "zh-Hans": "您的充电习惯非常温和，极利于保护电池组健康。",
        "ja": "あなたの充電習慣はバッテリーに非常に優しく、理想的です。",
        "nb": "Ladevanene dine er svært skånsomme for batteripakken.",
        "th": "พฤติกรรมการชาร์จของคุณมีความอ่อนโยนและช่วยถนอมแบตเตอรี่ได้อย่างดีเยี่ยม"
    },
    "Your charging habits are generally healthy with solid battery preservation.": {
        "en": "Your charging habits are generally healthy with solid battery preservation.",
        "de": "Ihre Ladeangewohnheiten sind im Allgemeinen gesund und schonend für den Akku.",
        "fr": "Vos habitudes de recharge sont globalement saines et préservent bien la batterie.",
        "es": "Sus hábitos de carga son generalmente saludables para la batería.",
        "zh-Hans": "您的充电习惯总体健康，具有良好的电池保养效果。",
        "ja": "充電習慣は全般的に良好で、バッテリーがしっかりと保護されています。",
        "nb": "Ladevanene dine er generelt sunne og bevarer batteriet godt.",
        "th": "พฤติกรรมการชาร์จของคุณอยู่ในเกณฑ์ดีและช่วยรักษาอายุการใช้งานแบตเตอรี่"
    },
    "Your charging routine causes moderate thermal or voltage stress on your battery pack.": {
        "en": "Your charging routine causes moderate thermal or voltage stress on your battery pack.",
        "de": "Ihre Laderoutine verursacht mäßige thermische oder spannungsbedingte Belastungen für den Akku.",
        "fr": "Votre routine de recharge cause un stress thermique ou de tension modéré à votre batterie.",
        "es": "Su rutina de carga causa estrés térmico o de voltaje moderado en la batería.",
        "zh-Hans": "您的充电习惯对电池组造成了一定程度的热应力或高压损耗。",
        "ja": "充電ルーチンによってバッテリーに中程度の熱負荷または電圧負荷がかかっています。",
        "nb": "Laderutinene dine forårsaker moderat termisk eller spenningsrelatert belastning på batteriet.",
        "th": "กิจวัตรการชาร์จของคุณสร้างความร้อนหรือความเค้นระดับปานกลางต่อแบตเตอรี่"
    },
    "Frequent high-stress charging patterns detected that may accelerate battery degradation.": {
        "en": "Frequent high-stress charging patterns detected that may accelerate battery degradation.",
        "de": "Es wurden häufige Hochbelastungsmuster erkannt, die die Alterung beschleunigen können.",
        "fr": "Des habitudes à fort stress ont été détectées, risquant d'accélérer la dégradation.",
        "es": "Se detectaron patrones de carga de alto estrés que pueden acelerar la degradación.",
        "zh-Hans": "检测到频繁的高损耗充电模式，可能会加速电池容量衰减。",
        "ja": "劣化を早める可能性のある高負荷な充電パターンが頻繁に検出されています。",
        "nb": "Hyppige høystress-lademønstre oppdaget som kan akselerere batteridegraderingen.",
        "th": "ตรวจพบรูปแบบการชาร์จที่มีภาระสูงบ่อยครั้ง ซึ่งอาจเร่งให้แบตเตอรี่เสื่อมเร็วขึ้น"
    },
    "Your LFP battery is overdue for a 100% AC calibration charge to balance cell voltages.": {
        "en": "Your LFP battery is overdue for a 100% AC calibration charge to balance cell voltages.",
        "de": "Ihr LFP-Akku benötigt dringend eine 100%-AC-Ladung zum Ausbalancieren der Zellspannungen.",
        "fr": "Votre batterie LFP a besoin d'une charge d'étalonnage AC à 100 % pour équilibrer les cellules.",
        "es": "Su batería LFP necesita una carga de calibración en CA al 100% para equilibrar celdas.",
        "zh-Hans": "您的 LFP 电池急需进行一次 100% 交流充满校准，以平衡各单体电芯电压。",
        "ja": "LFPバッテリーのセル電圧を平衡化するため、100%の普通充電による校正が必要です。",
        "nb": "LFP-batteriet trenger en 100 % AC-kalibreringslading for å balansere cellene.",
        "th": "แบตเตอรี่ LFP ของคุณควรได้รับการชาร์จ AC เต็ม 100% เพื่อปรับสมดุลแรงดันไฟฟ้าของเซลล์"
    },
    "Regular AC charging and periodic 100% calibration will keep your LFP cells balanced.": {
        "en": "Regular AC charging and periodic 100% calibration will keep your LFP cells balanced.",
        "de": "Regelmäßiges AC-Laden und periodische 100%-Kalibrierung halten die LFP-Zellen im Gleichgewicht.",
        "fr": "Une recharge AC régulière et une calibration périodique à 100 % maintiennent les cellules LFP équilibrées.",
        "es": "La carga regular en CA y calibraciones al 100% mantendrán equilibradas las celdas LFP.",
        "zh-Hans": "经常使用慢充并定期充满至 100% 可保持 LFP 电芯良好均衡。",
        "ja": "定期的な普通充電と100%校正により、LFPセルのバランスが保たれます。",
        "nb": "Jevnlig AC-lading og periodisk 100 % kalibrering holder LFP-cellene balansert.",
        "th": "การชาร์จ AC เป็นประจำและการปรับเทียบ 100% เป็นระยะจะช่วยรักษาสมดุลของเซลล์ LFP"
    },
    "Setting an 80%–90% daily charge limit will significantly reduce high-voltage cathode stress.": {
        "en": "Setting an 80%–90% daily charge limit will significantly reduce high-voltage cathode stress.",
        "de": "Ein tägliches Limit von 80%–90% verringert die Kathodenspannung und schützt den Akku.",
        "fr": "Régler une limite quotidienne de 80 %–90 % réduira considérablement le stress de la cathode.",
        "es": "Establecer un límite diario de 80%–90% reducirá el estrés por alto voltaje en el cátodo.",
        "zh-Hans": "将日常充电上限设定为 80%–90% 可显著减轻正极高电压损耗。",
        "ja": "日常の充電上限を80%〜90%に設定すると、正極の高電圧負荷が大幅に軽減されます。",
        "nb": "Å sette en daglig grense på 80 %–90 % vil redusere høyspenningsbelastningen betydelig.",
        "th": "การตั้งขีดจำกัดการชาร์จรายวันไว้ที่ 80%–90% จะช่วยลดความเค้นจากแรงดันสูงที่ขั้วแคโทดได้อย่างมาก"
    },
    "Maintaining an 80% daily charge ceiling keeps your NMC/NCA cells in the optimal longevity window.": {
        "en": "Maintaining an 80% daily charge ceiling keeps your NMC/NCA cells in the optimal longevity window.",
        "de": "Ein tägliches 80%-Limit hält Ihre NMC/NCA-Zellen im optimalen Lebensdauerbereich.",
        "fr": "Maintenir un plafond quotidien de 80 % garde vos cellules NMC/NCA dans la plage idéale de longévité.",
        "es": "Mantener un límite diario del 80% mantiene las celdas NMC/NCA en su ventana óptima de vida útil.",
        "zh-Hans": "保持 80% 的日常充电上限可使 NMC/NCA 电芯始终处于最佳长寿区间。",
        "ja": "日常80%の上限を維持することで、NMC/NCAセルが最も長持ちする状態を保てます。",
        "nb": "Et daglig 80 % tak holder NMC/NCA-cellene i det optimale levetidsvinduet.",
        "th": "การรักษาเพดานการชาร์จรายวันที่ 80% จะช่วยให้เซลล์ NMC/NCA อยู่ในเกณฑ์อายุการใช้งานสูงสุด"
    },
    "Log your AC and DC charging sessions with start and end battery percentages to unlock detailed battery health insights.": {
        "en": "Log your AC and DC charging sessions with start and end battery percentages to unlock detailed battery health insights.",
        "de": "Erfassen Sie Ladevorgänge mit Start- und End-SoC, um detaillierte Batterieanalysen freizuschalten.",
        "fr": "Enregistrez vos sessions avec les pourcentages de début et de fin pour débloquer les analyses détaillées.",
        "es": "Registre sesiones con porcentajes iniciales y finales para desbloquear análisis detallados.",
        "zh-Hans": "记录包含起始和结束电量百分比的充放电数据，以解锁全面的电池健康洞察。",
        "ja": "開始と終了のSoCを記録すると、詳細なバッテリー健康分析が確認できるようになります。",
        "nb": "Loggfør ladeøkter med start- og sluttprosent for å låse opp detaljert batterihelseinnsikt.",
        "th": "บันทึกการชาร์จพร้อมระบุเปอร์เซ็นต์แบตเตอรี่เริ่มต้นและสิ้นสุด เพื่อปลดล็อกการวิเคราะห์สุขภาพแบตเตอรี่โดยละเอียด"
    },
    "You primarily use gentle AC slow charging, keeping cell temperatures low and protecting the Solid Electrolyte Interphase (SEI) layer.": {
        "en": "You primarily use gentle AC slow charging, keeping cell temperatures low and protecting the Solid Electrolyte Interphase (SEI) layer.",
        "de": "Sie nutzen überwiegend schonendes AC-Laden, was die Zelltemperaturen niedrig hält und die SEI-Schicht schützt.",
        "fr": "Vous utilisez principalement la charge lente AC, maintenant des températures basses et protégeant la couche SEI.",
        "es": "Utiliza principalmente carga lenta de CA, manteniendo bajas las temperaturas y protegiendo la capa SEI.",
        "zh-Hans": "您主要使用温和的交流慢充，使电芯保持较低温度并保护 SEI 膜。",
        "ja": "主に穏やかな普通充電（AC）を使用しており、セル温度を低く保ちSEI被膜を保護しています。",
        "nb": "Du bruker primært skånsom AC-saktelading, noe som holder celletemperaturen lav og beskytter SEI-laget.",
        "th": "คุณชาร์จด้วยไฟกระแสสลับ AC เป็นหลัก ช่วยให้อุณหภูมิเซลล์ต่ำและถนอมชั้น SEI ได้อย่างดี"
    },
    "A significant portion of your energy comes from high-power DC fast charging.": {
        "en": "A significant portion of your energy comes from high-power DC fast charging.",
        "de": "Ein beträchtlicher Teil Ihrer Energie stammt aus DC-Schnellladungen mit hoher Leistung.",
        "fr": "Une part importante de votre énergie provient de la charge rapide DC haute puissance.",
        "es": "Una parte significativa de su energía proviene de carga rápida en CC de alta potencia.",
        "zh-Hans": "您充入的大部分电量来自大功率直流快充。",
        "ja": "エネルギーの多くを高出力な急速充電（DC）から取得しています。",
        "nb": "En betydelig del av energien din kommer fra kraftig DC-hurtiglading.",
        "th": "พลังงานส่วนใหญ่ของคุณมาจากการชาร์จเร็ว DC กำลังสูง"
    },
    "Good mix of AC daily charging and occasional DC road trip fast charging.": {
        "en": "Good mix of AC daily charging and occasional DC road trip fast charging.",
        "de": "Gute Mischung aus täglichem AC-Laden und gelegentlichem DC-Schnellladen auf Reisen.",
        "fr": "Bon équilibre entre recharge quotidienne AC et recharge rapide DC sur longs trajets.",
        "es": "Buena combinación de carga diaria en CA y carga rápida ocasional en viajes.",
        "zh-Hans": "日常交流慢充与长途直流快充搭配合理。",
        "ja": "日常の普通充電と旅行時の急速充電が良いバランスで組み合わされています。",
        "nb": "God blanding av daglig AC-lading og sporadisk DC-hurtiglading på tur.",
        "th": "การผสมผสานที่ดีระหว่างการชาร์จ AC ประจำวันและการชาร์จเร็ว DC เมื่อเดินทางไกล"
    },
    "You regularly charge your LFP battery to 100%, enabling the Battery Management System to balance cell voltages.": {
        "en": "You regularly charge your LFP battery to 100%, enabling the Battery Management System to balance cell voltages.",
        "de": "Sie laden Ihren LFP-Akku regelmäßig auf 100%, sodass das BMS die Zellspannungen abgleichen kann.",
        "fr": "Vous chargez régulièrement votre batterie LFP à 100 %, permettant au BMS d'équilibrer les cellules.",
        "es": "Carga regularmente su batería LFP al 100%, permitiendo al BMS equilibrar los voltajes de las celdas.",
        "zh-Hans": "您经常将 LFP 电池充满至 100%，让电池管理系统能够平衡各单体电芯电压。",
        "ja": "定期的にLFPバッテリーを100%まで充電しており、BMSがセル電圧を適切にバランシングできています。",
        "nb": "Du lader regelmessig LFP-batteriet til 100 %, slik at BMS kan balansere cellespenningene.",
        "th": "คุณชาร์จแบตเตอรี่ LFP เต็ม 100% เป็นประจำ ทำให้ระบบ BMS สามารถปรับสมดุลแรงดันไฟฟ้าของเซลล์ได้อย่างต่อเนื่อง"
    },
    "You regularly charge to 100%, keeping your LFP battery cells balanced.": {
        "en": "You regularly charge to 100%, keeping your LFP battery cells balanced.",
        "de": "Sie laden regelmäßig auf 100% und halten Ihre LFP-Zellen so im Gleichgewicht.",
        "fr": "Vous chargez régulièrement à 100 %, maintenant vos cellules LFP équilibrées.",
        "es": "Carga regularmente al 100%, manteniendo equilibradas las celdas LFP.",
        "zh-Hans": "您定期充至 100%，有效保持了 LFP 电芯的一致性与平衡。",
        "ja": "定期的に100%まで充電し、LFPバッテリーのセルバランスを良好に保っています。",
        "nb": "Du lader jevnlig til 100 % og holder LFP-cellene balansert.",
        "th": "คุณชาร์จเต็ม 100% เป็นประจำ ช่วยรักษาเซลล์แบตเตอรี่ LFP ให้สมดุลเสมอ"
    },
    "None of your logged sessions reached 100% SoC.": {
        "en": "None of your logged sessions reached 100% SoC.",
        "de": "Keiner der erfassten Ladevorgänge hat 100% SoC erreicht.",
        "fr": "Aucune de vos sessions enregistrées n'a atteint 100 % de SoC.",
        "es": "Ninguna de sus sesiones registradas alcanzó el 100% de SoC.",
        "zh-Hans": "您记录的充电均未达到 100% 满电状态。",
        "ja": "記録されたセッションの中に100%まで充電されたものがありません。",
        "nb": "Ingen av de loggførte øktene nådde 100 % SoC.",
        "th": "ไม่มีรายการชาร์จที่บันทึกไว้ครั้งใดที่ชาร์จถึง 100% SoC"
    },
    "You avoid charging to 100% on everyday commutes, protecting your NMC/NCA battery from high-voltage stress.": {
        "en": "You avoid charging to 100% on everyday commutes, protecting your NMC/NCA battery from high-voltage stress.",
        "de": "Sie vermeiden 100%-Ladungen im Alltag und schützen Ihren NMC/NCA-Akku vor Hochspannungsstress.",
        "fr": "Vous évitez de charger à 100 % au quotidien, protégeant votre batterie NMC/NCA de la haute tension.",
        "es": "Evita cargar al 100% en trayectos diarios, protegiendo su batería NMC/NCA del alto voltaje.",
        "zh-Hans": "您在日常通勤中避免充满至 100%，有效保护了 NMC/NCA 电池免受高电压损害。",
        "ja": "日常の通勤で100%充電を避けており、NMC/NCAバッテリーの高電圧ストレスを防いでいます。",
        "nb": "Du unngår å lade til 100 % til daglig, noe som beskytter NMC/NCA-batteriet mot høyspent stress.",
        "th": "คุณหลีกเลี่ยงการชาร์จถึง 100% ในการขับขี่ประจำวัน ช่วยปกป้องแบตเตอรี่ NMC/NCA จากแรงดันไฟฟ้าสูง"
    },
    "Several charges started below 15% State of Charge.": {
        "en": "Several charges started below 15% State of Charge.",
        "de": "Mehrere Ladevorgänge starteten unter 15% SoC.",
        "fr": "Plusieurs recharges ont débuté sous les 15 % de SoC.",
        "es": "Varias cargas comenzaron por debajo del 15% de SoC.",
        "zh-Hans": "有多次充电是在电量低于 15% 时才开始的。",
        "ja": "15%未満の残量から開始された充電が複数回あります。",
        "nb": "Flere ladeøkter startet under 15 % SoC.",
        "th": "มีการชาร์จหลายครั้งที่เริ่มเสียบเมื่อแบตเตอรี่ต่ำกว่า 15%"
    },
    "You consistently recharge before your battery drops into deep discharge territory.": {
        "en": "You consistently recharge before your battery drops into deep discharge territory.",
        "de": "Sie laden stets nach, bevor der Akku in den Tiefentladungsbereich gerät.",
        "fr": "Vous rechargez systématiquement avant que la batterie n'entre en décharge profonde.",
        "es": "Recarga constantemente antes de que la batería caiga en descarga profunda.",
        "zh-Hans": "您总是在电池进入深度放电区间之前及时充电。",
        "ja": "バッテリーが深放電領域に入る前に常に充電できています。",
        "nb": "Du lader konsekvent før batteriet faller ned i dyp utlading.",
        "th": "คุณเสียบชาร์จใหม่อย่างสม่ำเสมอก่อนที่แบตเตอรี่จะลดลงสู่ระดับคายประจุลึก"
    },
    "Enter charging sessions whenever you top up.": {
        "en": "Enter charging sessions whenever you top up.",
        "de": "Erfassen Sie Ladevorgänge nach jedem Laden.",
        "fr": "Saisissez vos sessions de recharge à chaque fois que vous faites le plein.",
        "es": "Ingrese las sesiones de carga cada vez que recargue.",
        "zh-Hans": "每次充电后及时记录充入的数据。",
        "ja": "充電するたびにセッションを入力してください。",
        "nb": "Legg inn ladeøkter hver gang du lader.",
        "th": "บันทึกข้อมูลการชาร์จทุกครั้งที่คุณเติมไฟ"
    },
    "Continue using AC home/work chargers for regular daily commutes.": {
        "en": "Continue using AC home/work chargers for regular daily commutes.",
        "de": "Nutzen Sie weiterhin AC-Lader zu Hause oder am Arbeitsplatz für den Alltag.",
        "fr": "Continuez d'utiliser les bornes AC à domicile/au travail pour vos trajets réguliers.",
        "es": "Continúe usando cargadores de CA en casa/trabajo para el uso diario.",
        "zh-Hans": "日常通勤请继续使用家用或工作场所的交流慢充桩。",
        "ja": "日常の通勤には引き続き自宅や職場の普通充電器をご利用ください。",
        "nb": "Fortsett å bruke AC-ladere hjemme/på jobb for daglig pendling.",
        "th": "ใช้งานที่ชาร์จ AC ที่บ้านหรือที่ทำงานต่อไปสำหรับการเดินทางประจำวัน"
    },
    "Prioritize AC slow charging at home or destination chargers whenever feasible, reserving DC fast charging for long-distance trips.": {
        "en": "Prioritize AC slow charging at home or destination chargers whenever feasible, reserving DC fast charging for long-distance trips.",
        "de": "Bevorzugen Sie wenn möglich AC-Langsamer an Zielorten und zu Hause; heben Sie DC für Langstrecken auf.",
        "fr": "Privilégiez la charge lente AC et réservez la charge rapide DC aux longs trajets.",
        "es": "Priorice la carga lenta de CA y reserve la carga rápida en CC para viajes largos.",
        "zh-Hans": "尽量优先在家或目的地使用交流慢充，将直流快充留给长途出行。",
        "ja": "可能な限り自宅や目的地の普通充電を優先し、急速充電は長距離移動用に限定してください。",
        "nb": "Prioriter AC-saktelading hjemme eller på destinasjoner, og spar DC-hurtiglading til langkjøring.",
        "th": "เลือกชาร์จช้า AC ที่บ้านหรือจุดหมายปลายทางเป็นหลัก และเก็บการชาร์จเร็ว DC ไว้ใช้เมื่อเดินทางไกล"
    },
    "Maintain current balance by keeping DC rapid charges below 30% of lifetime energy.": {
        "en": "Maintain current balance by keeping DC rapid charges below 30% of lifetime energy.",
        "de": "Behalten Sie diese Balance bei, indem DC-Schnellladungen unter 30% der Gesamtenergie bleiben.",
        "fr": "Maintenez cet équilibre en gardant les charges rapides DC sous les 30 % de l'énergie totale.",
        "es": "Mantenga el equilibrio manteniendo las cargas rápidas en CC por debajo del 30% del total.",
        "zh-Hans": "将直流快充能量控制在总电量的 30% 以下以保持当前良好平衡。",
        "ja": "急速充電の割合を生涯エネルギーの30%未満に抑えて現在のバランスを維持しましょう。",
        "nb": "Oppretthold balansen ved å holde DC-hurtiglading under 30 % av total energi.",
        "th": "รักษาสมดุลปัจจุบันโดยคุมการชาร์จเร็ว DC ให้น้อยกว่า 30% ของพลังงานทั้งหมด"
    },
    "Keep charging to 100% every 1–2 weeks.": {
        "en": "Keep charging to 100% every 1–2 weeks.",
        "de": "Laden Sie weiterhin alle 1–2 Wochen auf 100%.",
        "fr": "Continuez à charger à 100 % toutes les 1 à 2 semaines.",
        "es": "Siga cargando al 100% cada 1–2 semanas.",
        "zh-Hans": "继续保持每 1–2 周充满至 100% 一次的习惯。",
        "ja": "1〜2週間ごとに100%まで充電する習慣を継続してください。",
        "nb": "Fortsett å lade til 100 % hver 1.–2. uke.",
        "th": "ชาร์จเต็ม 100% ทุกๆ 1–2 สัปดาห์อย่างต่อเนื่อง"
    },
    "Plug into an AC charger and charge to 100% soon to let the BMS balance cells.": {
        "en": "Plug into an AC charger and charge to 100% soon to let the BMS balance cells.",
        "de": "Schließen Sie das Auto bald an einen AC-Lader an und laden Sie auf 100%, um die Zellen auszubalancieren.",
        "fr": "Branchez bientôt sur un chargeur AC et chargez à 100 % pour équilibrer les cellules.",
        "es": "Conecte pronto a un cargador de CA y cargue al 100% para equilibrar celdas.",
        "zh-Hans": "建议尽快连接交流慢充充满至 100%，以便 BMS 均衡电芯。",
        "ja": "近いうちに普通充電器に接続して100%まで充電し、BMSにセルバランスを行わせてください。",
        "nb": "Koble til en AC-lader snart og lad til 100 % slik at BMS får balansert cellene.",
        "th": "ควรเสียบชาร์จ AC ให้เต็ม 100% ในเร็วๆ นี้ เพื่อให้ระบบ BMS ปรับสมดุลเซลล์"
    },
    "Plan a 100% AC top-off in the coming week.": {
        "en": "Plan a 100% AC top-off in the coming week.",
        "de": "Planen Sie in der kommenden Woche eine 100%-AC-Ladung ein.",
        "fr": "Prévoyez une recharge complète AC à 100 % dans la semaine à venir.",
        "es": "Planifique una carga completa en CA al 100% en la próxima semana.",
        "zh-Hans": "请在接下来的一周内安排一次 100% 交流充满。",
        "ja": "来週中に普通充電で100%まで充電することを計画してください。",
        "nb": "Planlegg en 100 % AC-opplading i løpet av den kommende uken.",
        "th": "วางแผนชาร์จ AC ให้เต็ม 100% ภายในสัปดาห์นี้"
    },
    "Continue regular 100% charges on your LFP pack.": {
        "en": "Continue regular 100% charges on your LFP pack.",
        "de": "Fahren Sie mit den regelmäßigen 100%-Ladungen Ihres LFP-Akkus fort.",
        "fr": "Poursuivez les recharges régulières à 100 % sur votre pack LFP.",
        "es": "Continúe con las cargas regulares al 100% en su batería LFP.",
        "zh-Hans": "对您的 LFP 电池组继续保持定期的 100% 充满习惯。",
        "ja": "LFPバッテリーの定期的な100%充電を継続してください。",
        "nb": "Fortsett med regelmessig 100 % lading av LFP-batteriet.",
        "th": "ชาร์จแบตเตอรี่ LFP เต็ม 100% อย่างสม่ำเสมอต่อไป"
    },
    "Perform an AC slow charge to 100% at least once every 1–2 weeks.": {
        "en": "Perform an AC slow charge to 100% at least once every 1–2 weeks.",
        "de": "Führen Sie mindestens alle 1–2 Wochen eine AC-Langsamer-Ladung auf 100% durch.",
        "fr": "Effectuez une charge lente AC à 100 % au moins une fois toutes les 1 à 2 semaines.",
        "es": "Realice una carga lenta en CA al 100% al menos una vez cada 1–2 semanas.",
        "zh-Hans": "每 1–2 周至少进行一次交流慢充充满至 100%。",
        "ja": "1〜2週間に1回は普通充電で100%まで充電を行ってください。",
        "nb": "Utfør en AC-saktelading til 100 % minst én gang hver 1.–2. uke.",
        "th": "ทำการชาร์จช้า AC ให้เต็ม 100% อย่างน้อยทุกๆ 1–2 สัปดาห์"
    },
    "Set your vehicle charge limit to 80% (or 90%) for daily driving, reserving 100% only for long road trips.": {
        "en": "Set your vehicle charge limit to 80% (or 90%) for daily driving, reserving 100% only for long road trips.",
        "de": "Stellen Sie das Limit im Alltag auf 80% (oder 90%) und heben Sie 100% für Reisen auf.",
        "fr": "Réglez la limite à 80 % (ou 90 %) au quotidien, réservant le 100 % aux longs trajets.",
        "es": "Ajuste el límite al 80% (o 90%) para uso diario, reservando el 100% para viajes largos.",
        "zh-Hans": "将日常充电上限设为 80%（或 90%），仅在长途出行时才充至 100%。",
        "ja": "日常の充電上限を80%（または90%）に設定し、100%は長距離移動時のみに限定してください。",
        "nb": "Sett ladegrensen til 80 % (eller 90 %) til daglig, og spar 100 % til langkjøring.",
        "th": "ตั้งค่าขีดจำกัดการชาร์จไว้ที่ 80% (หรือ 90%) ในชีวิตประจำวัน และชาร์จ 100% เฉพาะเมื่อเดินทางไกล"
    },
    "Continue keeping daily limits between 80% and 90%.": {
        "en": "Continue keeping daily limits between 80% and 90%.",
        "de": "Behalten Sie das tägliche Limit zwischen 80% und 90% bei.",
        "fr": "Continuez de maintenir la limite quotidienne entre 80 % et 90 %.",
        "es": "Siga manteniendo los límites diarios entre el 80% y el 90%.",
        "zh-Hans": "继续将日常充电上限保持在 80% 到 90% 之间。",
        "ja": "日常の充電上限を80%〜90%の間に維持し続けてください。",
        "nb": "Fortsett å holde daglige grenser mellom 80 % og 90 %.",
        "th": "รักษาระดับการชาร์จรายวันไว้ระหว่าง 80% ถึง 90% ต่อไป"
    },
    "Aim to plug in before dropping below 15%–20% State of Charge.": {
        "en": "Aim to plug in before dropping below 15%–20% State of Charge.",
        "de": "Versuchen Sie anzustecken, bevor der SoC unter 15%–20% fällt.",
        "fr": "Essayez de brancher avant de descendre sous les 15 %–20 % de SoC.",
        "es": "Procure conectar antes de bajar del 15%–20% de SoC.",
        "zh-Hans": "尽量在电量降至 15%–20% 以下之前插枪充电。",
        "ja": "SoCが15%〜20%を下回る前に充電を開始するよう心がけてください。",
        "nb": "Sikt på å koble til før batteriet faller under 15 %–20 % SoC.",
        "th": "ตั้งเป้าหมายเสียบชาร์จก่อนที่แบตเตอรี่จะลดลงต่ำกว่า 15%–20%"
    },
    "Top up when reaching ~20% during normal commuting routines.": {
        "en": "Top up when reaching ~20% during normal commuting routines.",
        "de": "Im Alltag nachladen, sobald ca. 20% erreicht sind.",
        "fr": "Rechargez dès que vous atteignez environ 20 % au quotidien.",
        "es": "Recargue al llegar a ~20% en su rutina diaria.",
        "zh-Hans": "日常通勤中，在电量降至约 20% 时即可进行补能。",
        "ja": "日常の通勤では、残量が約20%になった時点で充電してください。",
        "nb": "Fyll på når du når ca. 20 % ved vanlig pendling.",
        "th": "เสียบชาร์จเติมเมื่อแบตเตอรี่ลดลงเหลือประมาณ 20% ในชีวิตประจำวัน"
    },
    "Continue maintaining a 15%+ discharge cushion.": {
        "en": "Continue maintaining a 15%+ discharge cushion.",
        "de": "Behalten Sie das Polster von mindestens 15% weiterhin bei.",
        "fr": "Continuez de maintenir une marge de sécurité de plus de 15 %.",
        "es": "Siga manteniendo un colchón de descarga del 15%+.",
        "zh-Hans": "继续保持 15% 以上的电量放电安全余量。",
        "ja": "15%以上の放電バッファを維持し続けてください。",
        "nb": "Fortsett å opprettholde en utladingsbuffer på over 15 %.",
        "th": "รักษาปริมาณแบตเตอรี่สำรองไม่ให้ต่ำกว่า 15% ต่อไป"
    },
    "0 sessions": {
        "en": "0 sessions",
        "de": "0 Ladevorgänge",
        "fr": "0 session",
        "es": "0 sesiones",
        "zh-Hans": "0 次记录",
        "ja": "0 セッション",
        "nb": "0 økter",
        "th": "0 ครั้ง"
    },
    "Well protected": {
        "en": "Well protected",
        "de": "Gut geschützt",
        "fr": "Bien protégé",
        "es": "Bien protegido",
        "zh-Hans": "保护良好",
        "ja": "良好に保護",
        "nb": "Godt beskyttet",
        "th": "ได้รับการถนอมอย่างดี"
    },
    "100% Calibrated": {
        "en": "100% Calibrated",
        "de": "100% kalibriert",
        "fr": "Calibré à 100 %",
        "es": "Calibrado al 100%",
        "zh-Hans": "已校准至 100%",
        "ja": "100%校正済み",
        "nb": "100 % kalibrert",
        "th": "ปรับเทียบ 100% แล้ว"
    },
    "Needs 100%": {
        "en": "Needs 100%",
        "de": "100% erforderlich",
        "fr": "Nécessite 100 %",
        "es": "Requiere 100%",
        "zh-Hans": "需要充至 100%",
        "ja": "100%充電が必要",
        "nb": "Trenger 100 %",
        "th": "ต้องชาร์จ 100%"
    },
    "Consistent cycles": {
        "en": "Consistent cycles",
        "de": "Gleichmäßige Zyklen",
        "fr": "Cycles cohérents",
        "es": "Ciclos constantes",
        "zh-Hans": "循环均匀",
        "ja": "一貫したサイクル",
        "nb": "Konsekvente sykluser",
        "th": "รอบชาร์จสม่ำเสมอ"
    },
    "Protected (>15%)": {
        "en": "Protected (>15%)",
        "de": "Geschützt (>15%)",
        "fr": "Protégé (>15 %)",
        "es": "Protegido (>15%)",
        "zh-Hans": "受保护 (>15%)",
        "ja": "保護済み (>15%)",
        "nb": "Beskyttet (>15 %)",
        "th": "ปลอดภัย (>15%)"
    },
    "Lithium Iron Phosphate (LFP / Blade)": {
        "en": "Lithium Iron Phosphate (LFP / Blade)",
        "de": "Lithium-Eisenphosphat (LFP / Blade)",
        "fr": "Lithium-fer-phosphate (LFP / Blade)",
        "es": "Fosfato de hierro y litio (LFP / Blade)",
        "zh-Hans": "磷酸铁锂 (LFP / 刀片电池)",
        "ja": "リン酸鉄リチウム (LFP / ブレード)",
        "nb": "Litium-jernfosfat (LFP / Blade)",
        "th": "ลิเธียมไอรอนฟอสเฟต (LFP / Blade)"
    },
    "Nickel Manganese Cobalt (NMC / NCM)": {
        "en": "Nickel Manganese Cobalt (NMC / NCM)",
        "de": "Nickel-Mangan-Cobalt (NMC / NCM)",
        "fr": "Nickel-manganèse-cobalt (NMC / NCM)",
        "es": "Níquel-manganeso-cobalto (NMC / NCM)",
        "zh-Hans": "镍锰钴三元锂 (NMC / NCM)",
        "ja": "ニッケル・マンガン・コバルト (NMC / NCM)",
        "nb": "Nikkel-mangan-kobolt (NMC / NCM)",
        "th": "นิกเกิลแมงกานีสโคบอลต์ (NMC / NCM)"
    },
    "Nickel Cobalt Aluminum (NCA)": {
        "en": "Nickel Cobalt Aluminum (NCA)",
        "de": "Nickel-Cobalt-Aluminium (NCA)",
        "fr": "Nickel-cobalt-aluminium (NCA)",
        "es": "Níquel-cobalto-aluminio (NCA)",
        "zh-Hans": "镍钴铝三元锂 (NCA)",
        "ja": "ニッケル・コバルト・アルミニウム (NCA)",
        "nb": "Nikkel-kobolt-aluminium (NCA)",
        "th": "นิกเกิลโคบอลต์อะลูมิเนียม (NCA)"
    },
    "Other / Custom Chemistry": {
        "en": "Other / Custom Chemistry",
        "de": "Andere / Benutzerdefinierte Chemie",
        "fr": "Autre / Chimie personnalisée",
        "es": "Otra / Composición personalizada",
        "zh-Hans": "其他 / 自定义电池类型",
        "ja": "その他 / カスタム化学種",
        "nb": "Annen / Tilpasset kjemi",
        "th": "อื่นๆ / แบตเตอรี่ที่กำหนดเอง"
    },
    "100% regular charge": {
        "en": "100% regular charge",
        "de": "Regulär auf 100% laden",
        "fr": "Charge régulière à 100 %",
        "es": "Carga regular al 100%",
        "zh-Hans": "常规充至 100%",
        "ja": "通常100%まで充電",
        "nb": "Regelmessig lading til 100 %",
        "th": "ชาร์จเต็ม 100% ได้เป็นประจำ"
    },
    "80%–90% daily limit": {
        "en": "80%–90% daily limit",
        "de": "80%–90% tägliches Limit",
        "fr": "Limite quotidienne 80 %–90 %",
        "es": "Límite diario 80%–90%",
        "zh-Hans": "日常上限 80%–90%",
        "ja": "日常は80%〜90%制限",
        "nb": "80 %–90 % daglig grense",
        "th": "จำกัดการชาร์จประจำวันไว้ที่ 80%–90%"
    },
    "Per manufacturer advice": {
        "en": "Per manufacturer advice",
        "de": "Gemäß Herstellerangaben",
        "fr": "Selon les conseils du constructeur",
        "es": "Según el fabricante",
        "zh-Hans": "按制造商建议",
        "ja": "メーカーの推奨に従う",
        "nb": "Iht. produsentens råd",
        "th": "ตามคำแนะนำของผู้ผลิต"
    },
    "Lithium Iron Phosphate (LFP) chemistry offers superior cycle life and thermal stability. Charge to 100% regularly (at least every 1–2 weeks) so the Battery Management System (BMS) can balance individual cells and accurately calibrate the SoC estimator.": {
        "en": "Lithium Iron Phosphate (LFP) chemistry offers superior cycle life and thermal stability. Charge to 100% regularly (at least every 1–2 weeks) so the Battery Management System (BMS) can balance individual cells and accurately calibrate the SoC estimator.",
        "de": "Lithium-Eisenphosphat (LFP) bietet herausragende Zyklenlebensdauer und thermische Stabilität. Laden Sie regelmäßig auf 100% (mindestens alle 1–2 Wochen), damit das BMS die Zellen ausbalancieren und den SoC kalibrieren kann.",
        "fr": "La chimie LFP offre une longévité et une stabilité thermique supérieures. Chargez à 100 % régulièrement (au moins toutes les 1 à 2 semaines) pour que le BMS équilibre les cellules et calibre l'estimateur de SoC.",
        "es": "El fosfato de hierro y litio (LFP) ofrece una vida útil y estabilidad térmica superiores. Cargue al 100% con regularidad (al menos cada 1–2 semanas) para que el BMS equilibre las celdas y calibre el SoC.",
        "zh-Hans": "磷酸铁锂 (LFP) 电池具备极高循环寿命与出色的热稳定性。建议定期充满至 100%（至少每 1–2 周一次），以便电池管理系统 (BMS) 均衡单体电芯并精准校准电量估算。",
        "ja": "リン酸鉄リチウム（LFP）は優れたサイクル寿命と熱安定性を備えています。BMSがセルバランスを行いSoC推定を校正できるよう、定期的に（1〜2週間に1回以上）100%まで充電してください。",
        "nb": "Litium-jernfosfat (LFP) gir overlegen sykluslevetid og termisk stabilitet. Lad regelmessig til 100 % (minst hver 1.–2. uke) slik at BMS kan balansere cellene og kalibrere SoC-estimatet.",
        "th": "แบตเตอรี่ลิเธียมไอรอนฟอสเฟต (LFP) มีอายุการใช้งานรอบชาร์จและความเสถียรทางความร้อนสูงเป็นพิเศษ ควรชาร์จเต็ม 100% เป็นประจำ (อย่างน้อยทุก 1–2 สัปดาห์) เพื่อให้ระบบ BMS ปรับสมดุลเซลล์และประเมินระดับแบตเตอรี่ได้อย่างแม่นยำ"
    },
    "Nickel Manganese Cobalt (NMC) chemistry provides high energy density. For daily driving, maintain a charge limit between 80% and 90% to avoid prolonged cathode voltage stress. Charge to 100% only prior to departure on long road trips.": {
        "en": "Nickel Manganese Cobalt (NMC) chemistry provides high energy density. For daily driving, maintain a charge limit between 80% and 90% to avoid prolonged cathode voltage stress. Charge to 100% only prior to departure on long road trips.",
        "de": "Nickel-Mangan-Cobalt (NMC) bietet hohe Energiedichte. Begrenzen Sie das Laden im Alltag auf 80%–90%, um Kathodenspannungsstress zu vermeiden. Laden Sie nur vor langen Fahrten auf 100%.",
        "fr": "La chimie NMC offre une haute densité énergétique. Au quotidien, maintenez une limite entre 80 % et 90 % pour éviter le stress haute tension. Réservez le 100 % aux longs trajets.",
        "es": "El níquel-manganeso-cobalto (NMC) ofrece alta densidad energética. En el día a día, mantenga el límite entre 80% y 90%. Cargue al 100% solo antes de viajes largos.",
        "zh-Hans": "镍锰钴三元锂 (NMC) 具有高能量密度。日常行驶请将充电限制设定在 80% 至 90% 之间，避免正极长期承受高电压。仅在长途出行出发前才充至 100%。",
        "ja": "ニッケル・マンガン・コバルト（NMC）は高いエネルギー密度を提供します。日常の走行では高電圧負荷を避けるため80%〜90%に制限し、100%充電は長距離ドライブ直前のみにしてください。",
        "nb": "Nikkel-mangan-kobolt (NMC) gir høy energitetthet. Hold daglig ladegrense på 80 %–90 % for å unngå høyspent stress. Lad til 100 % kun rett før langkjøring.",
        "th": "แบตเตอรี่นิกเกิลแมงกานีสโคบอลต์ (NMC) มีความหนาแน่นพลังงานสูง สำหรับการขับขี่ประจำวันควรจำกัดการชาร์จไว้ที่ 80%–90% เพื่อหลีกเลี่ยงความเค้นแรงดันสูง และชาร์จเต็ม 100% เฉพาะก่อนออกเดินทางไกลเท่านั้น"
    },
    "Nickel Cobalt Aluminum (NCA) chemistry delivers high energy density and power output. Limit daily charging to 80%–90% to prolong cell health, reserving 100% top-offs for immediate road trip departures.": {
        "en": "Nickel Cobalt Aluminum (NCA) chemistry delivers high energy density and power output. Limit daily charging to 80%–90% to prolong cell health, reserving 100% top-offs for immediate road trip departures.",
        "de": "Nickel-Cobalt-Aluminium (NCA) liefert hohe Energiedichte und Leistung. Begrenzen Sie das tägliche Laden auf 80%–90% und heben Sie 100% für anstehende Reisen auf.",
        "fr": "La chimie NCA offre une forte densité énergétique et de puissance. Limitez la charge quotidienne à 80 %–90 % et réservez le 100 % aux départs en voyage.",
        "es": "El níquel-cobalto-aluminio (NCA) ofrece alta densidad energética y potencia. Limite la carga diaria al 80%–90%, reservando el 100% para viajes largos.",
        "zh-Hans": "镍钴铝三元锂 (NCA) 兼具高能量密度与强劲功率。日常请将充电上限限制在 80%–90% 以延长电芯寿命，仅在长途出行前充满 100%。",
        "ja": "ニッケル・コバルト・アルミニウム（NCA）は高いエネルギー密度と出力を誇ります。日常の充電は80%〜90%に制限し、100%充電は長距離移動時のみに限定してください。",
        "nb": "Nikkel-kobolt-aluminium (NCA) leverer høy energitetthet og ytelse. Begrens daglig lading til 80 %–90 %, og spar 100 % til umiddelbar avreise på langtur.",
        "th": "แบตเตอรี่นิกเกิลโคบอลต์อะลูมิเนียม (NCA) ให้ความหนาแน่นพลังงานและกำลังขับเคลื่อนสูง ควรจำกัดการชาร์จรายวันไว้ที่ 80%–90% เพื่อถนอมเซลล์ และชาร์จ 100% เฉพาะก่อนออกเดินทางไกลทันที"
    },
    "Follow your vehicle manufacturer's recommendations for daily charging targets and periodic cell balancing.": {
        "en": "Follow your vehicle manufacturer's recommendations for daily charging targets and periodic cell balancing.",
        "de": "Befolgen Sie die Empfehlungen des Fahrzeugherstellers zu täglichen Ladezielen und Zellbalancierung.",
        "fr": "Suivez les recommandations du constructeur pour les cibles de charge quotidiennes et l'équilibrage des cellules.",
        "es": "Siga las recomendaciones del fabricante para los objetivos diarios de carga y el equilibrado de celdas.",
        "zh-Hans": "请遵循车辆制造商关于日常充电目标和定期电芯均衡的官方建议。",
        "ja": "日常の充電目標や定期的なセルバランシングについては、車両メーカーの推奨事項に従ってください。",
        "nb": "Følg bilprodusentens anbefalinger for daglige lademål og periodisk cellebalansering.",
        "th": "ปฏิบัติตามคำแนะนำของผู้ผลิตรถยนต์สำหรับเป้าหมายการชาร์จประจำวันและการปรับสมดุลเซลล์"
    },
    "WLTP (Worldwide Harmonized)": {
        "en": "WLTP (Worldwide Harmonized)",
        "de": "WLTP (Weltweit harmonisiert)",
        "fr": "WLTP (Harmonisé mondial)",
        "es": "WLTP (Armonizado mundial)",
        "zh-Hans": "WLTP (全球统一工况)",
        "ja": "WLTP (世界調和基準)",
        "nb": "WLTP (Verdensharmonisert)",
        "th": "WLTP (มาตรฐานสากล)"
    },
    "NEDC (New European Cycle)": {
        "en": "NEDC (New European Cycle)",
        "de": "NEFZ (Neuer Europäischer Fahrzyklus)",
        "fr": "NEDC (Nouveau cycle européen)",
        "es": "NEDC (Nuevo ciclo europeo)",
        "zh-Hans": "NEDC (新欧洲工况)",
        "ja": "NEDC (新欧州サイクル)",
        "nb": "NEDC (Ny europeisk kjøresyklus)",
        "th": "NEDC (มาตรฐานยุโรป)"
    },
    "CLTC (China Light-Duty Cycle)": {
        "en": "CLTC (China Light-Duty Cycle)",
        "de": "CLTC (China Light-Duty Cycle)",
        "fr": "CLTC (Cycle léger Chine)",
        "es": "CLTC (Ciclo ligero de China)",
        "zh-Hans": "CLTC (中国轻型汽车行驶工况)",
        "ja": "CLTC (中国小型車サイクル)",
        "nb": "CLTC (Kina lett kjøretøysyklus)",
        "th": "CLTC (มาตรฐานจีน)"
    },
    "EPA (US Environmental Protection)": {
        "en": "EPA (US Environmental Protection)",
        "de": "EPA (US-Umweltbehörde)",
        "fr": "EPA (Protection environnementale US)",
        "es": "EPA (Protección ambiental de EE. UU.)",
        "zh-Hans": "EPA (美国环保署标准)",
        "ja": "EPA (米国環境保護庁基準)",
        "nb": "EPA (US miljøvernbyrå)",
        "th": "EPA (มาตรฐานสหรัฐอเมริกา)"
    },
    "Custom Range Standard": {
        "en": "Custom Range Standard",
        "de": "Benutzerdefinierter Reichweitenstandard",
        "fr": "Norme d'autonomie personnalisée",
        "es": "Estándar de autonomía personalizado",
        "zh-Hans": "自定义续航标准",
        "ja": "カスタム航続距離基準",
        "nb": "Tilpasset rekkeviddestandard",
        "th": "มาตรฐานระยะทางที่กำหนดเอง"
    },
    "High (>= 30% DoD, clean interval)": {
        "en": "High (>= 30% DoD, clean interval)",
        "de": "Hoch (>= 30% DoD, sauberes Intervall)",
        "fr": "Élevée (>= 30 % DoD, intervalle propre)",
        "es": "Alta (>= 30% DoD, intervalo limpio)",
        "zh-Hans": "高置信度 (>= 30% 放电深度，有效区间)",
        "ja": "高精度 (>= 30% DoD、適切な充電区間)",
        "nb": "Høy (>= 30 % DoD, rent intervall)",
        "th": "ความเชื่อมั่นสูง (>= 30% DoD, ช่วงชาร์จสมบูรณ์)"
    },
    "Medium (15%–30% DoD)": {
        "en": "Medium (15%–30% DoD)",
        "de": "Mittel (15%–30% DoD)",
        "fr": "Moyenne (15 %–30 % DoD)",
        "es": "Media (15%–30% DoD)",
        "zh-Hans": "中置信度 (15%–30% 放电深度)",
        "ja": "中精度 (15%〜30% DoD)",
        "nb": "Middels (15 %–30 % DoD)",
        "th": "ความเชื่อมั่นปานกลาง (15%–30% DoD)"
    },
    "Low (< 15% DoD, high error margin)": {
        "en": "Low (< 15% DoD, high error margin)",
        "de": "Niedrig (< 15% DoD, hohe Fehlertoleranz)",
        "fr": "Faible (< 15 % DoD, marge d'erreur élevée)",
        "es": "Baja (< 15% DoD, alto margen de error)",
        "zh-Hans": "低置信度 (< 15% 放电深度，误差较大)",
        "ja": "低精度 (< 15% DoD、誤差が大きいです)",
        "nb": "Lav (< 15 % DoD, høy feilmargin)",
        "th": "ความเชื่อมั่นต่ำ (< 15% DoD, ค่าคลาดเคลื่อนสูง)"
    },
    "Unreliable (Shallow / Inconsistent)": {
        "en": "Unreliable (Shallow / Inconsistent)",
        "de": "Unzuverlässig (Zu flach / Inkonsistent)",
        "fr": "Non fiable (Trop court / Incohérent)",
        "es": "No confiable (Superficial / Inconsistente)",
        "zh-Hans": "不可靠 (浅充或数据不一致)",
        "ja": "信頼性低 (浅い充電 / 不整合)",
        "nb": "Upålitelig (Grunn / Inkonsekvent)",
        "th": "ไม่น่าเชื่อถือ (ชาร์จตื้นเกินไป / ข้อมูลไม่สอดคล้อง)"
    },
    "Excellent Health": {
        "en": "Excellent Health",
        "de": "Hervorragender Zustand",
        "fr": "Excellente santé",
        "es": "Salud excelente",
        "zh-Hans": "极佳健康度",
        "ja": "極めて良好",
        "nb": "Utmerket helse",
        "th": "สุขภาพแบตเตอรี่ดีเยี่ยม"
    },
    "Good Health": {
        "en": "Good Health",
        "de": "Guter Zustand",
        "fr": "Bonne santé",
        "es": "Buena salud",
        "zh-Hans": "良好健康度",
        "ja": "良好",
        "nb": "God helse",
        "th": "สุขภาพแบตเตอรี่ดี"
    },
    "Normal Degradation": {
        "en": "Normal Degradation",
        "de": "Normale Alterung",
        "fr": "Dégradation normale",
        "es": "Degradación normal",
        "zh-Hans": "正常衰减",
        "ja": "通常劣化",
        "nb": "Normal degradering",
        "th": "การเสื่อมสภาพตามปกติ"
    },
    "Accelerated Degradation": {
        "en": "Accelerated Degradation",
        "de": "Beschleunigte Alterung",
        "fr": "Dégradation accélérée",
        "es": "Degradación acelerada",
        "zh-Hans": "衰减较快",
        "ja": "劣化進行",
        "nb": "Akselerert degradering",
        "th": "การเสื่อมสภาพเร็วกว่าปกติ"
    },
    "Capacity retention is outstanding and well within factory degradation tolerances.": {
        "en": "Capacity retention is outstanding and well within factory degradation tolerances.",
        "de": "Die Kapazitätserhaltung ist hervorragend und liegt voll im Rahmen der Werkstoleranzen.",
        "fr": "La rétention de capacité est remarquable et conforme aux tolérances d'usine.",
        "es": "La retención de capacidad es excelente y está dentro de las tolerancias de fábrica.",
        "zh-Hans": "电池容量保持率极佳，完全处于出厂衰减容限之内。",
        "ja": "容量保持率は極めて高く、工場の劣化許容範囲内に収まっています。",
        "nb": "Kapasitetsbevaringen er enestående og godt innenfor fabrikkens toleranser.",
        "th": "การรักษาความจุแบตเตอรี่อยู่ในเกณฑ์ยอดเยี่ยมและอยู่ในเกณฑ์มาตรฐานโรงงาน"
    },
    "Pack degradation is tracking within normal parameters for age and cycle count.": {
        "en": "Pack degradation is tracking within normal parameters for age and cycle count.",
        "de": "Die Alterung des Akkupacks liegt im normalen Rahmen für Alter und Zyklenanzahl.",
        "fr": "La dégradation du pack suit les paramètres normaux pour son âge et ses cycles.",
        "es": "La degradación del pack sigue los parámetros normales para su edad y ciclos.",
        "zh-Hans": "电池组衰退符合其车龄及循环次数的正常预期水平。",
        "ja": "バッテリーの劣化は、年数とサイクル数に応じた正常な範囲内です。",
        "nb": "Batteridegraderingen følger normale parametere for alder og syklustall.",
        "th": "การเสื่อมสภาพของแบตเตอรี่อยู่ในเกณฑ์ปกติสำหรับอายุการใช้งานและจำนวนรอบชาร์จ"
    },
    "Capacity loss is in line with expected fleet averages for this chemistry.": {
        "en": "Capacity loss is in line with expected fleet averages for this chemistry.",
        "de": "Der Kapazitätsverlust entspricht dem erwarteten Flottendurchschnitt dieser Chemie.",
        "fr": "La perte de capacité correspond à la moyenne attendue pour cette chimie.",
        "es": "La pérdida de capacidad se ajusta a la media esperada para esta química.",
        "zh-Hans": "容量衰减符合该电池类型同类车队的平均预期。",
        "ja": "容量低下は、この化学種における想定平均値と同等です。",
        "nb": "Kapasitetstapet er i tråd med forventet flåtegjennomsnitt for denne kjemien.",
        "th": "การลดลงของความจุสอดคล้องกับค่าเฉลี่ยของแบตเตอรี่ประเภทนี้"
    },
    "Higher than expected capacity loss. Consider reviewing charging habits and high-heat DC charging frequency.": {
        "en": "Higher than expected capacity loss. Consider reviewing charging habits and high-heat DC charging frequency.",
        "de": "Höherer Kapazitätsverlust als erwartet. Ladeangewohnheiten und DC-Schnellladen bei Hitze prüfen.",
        "fr": "Perte de capacité plus élevée que prévu. Pensez à revoir vos habitudes et la fréquence de charge DC par forte chaleur.",
        "es": "Pérdida de capacidad superior a la esperada. Revise los hábitos de carga y la frecuencia de carga rápida en calor.",
        "zh-Hans": "容量衰减略高于预期。建议检查日常充电习惯并减少高温环境下的直流快充频率。",
        "ja": "想定以上の容量低下が見られます。充電習慣や高温下での急速充電頻度の見直しを検討してください。",
        "nb": "Høyere kapasitetstap enn forventet. Vurder å gjennomgå ladevaner og frekvens av DC-hurtiglading i varme.",
        "th": "การสูญเสียความจุสูงกว่าที่คาดไว้ แนะนำให้ทบทวนพฤติกรรมการชาร์จและลดความถี่ในการชาร์จเร็ว DC ในสภาพอากาศร้อน"
    },
    "Driving Efficiency — Recent (%@)": {
        "en": "Driving Efficiency — Recent (%1$@)",
        "de": "Fahreffizienz — Kürzlich (%1$@)",
        "fr": "Efficacité énergétique — Récente (%1$@)",
        "es": "Eficiencia de conducción — Reciente (%1$@)",
        "zh-Hans": "行驶能效 — 近期 (%1$@)",
        "ja": "電費効率 — 最近 (%1$@)",
        "nb": "Kjøreeffektivitet — Nylig (%1$@)",
        "th": "ประสิทธิภาพการขับขี่ — ล่าสุด (%1$@)"
    },
    "Driving Efficiency — Recent": {
        "en": "Driving Efficiency — Recent",
        "de": "Fahreffizienz — Kürzlich",
        "fr": "Efficacité énergétique — Récente",
        "es": "Eficiencia de conducción — Reciente",
        "zh-Hans": "行驶能效 — 近期",
        "ja": "電費効率 — 最近",
        "nb": "Kjøreeffektivitet — Nylig",
        "th": "ประสิทธิภาพการขับขี่ — ล่าสุด"
    },
    "Driving Efficiency -- Recent (%@)": {
        "en": "Driving Efficiency -- Recent (%1$@)",
        "de": "Fahreffizienz -- Kürzlich (%1$@)",
        "fr": "Efficacité énergétique -- Récente (%1$@)",
        "es": "Eficiencia de conducción -- Reciente (%1$@)",
        "zh-Hans": "行驶能效 -- 近期 (%1$@)",
        "ja": "電費効率 -- 最近 (%1$@)",
        "nb": "Kjøreeffektivitet -- Nylig (%1$@)",
        "th": "ประสิทธิภาพการขับขี่ -- ล่าสุด (%1$@)"
    },
    "Driving Efficiency -- Recent": {
        "en": "Driving Efficiency -- Recent",
        "de": "Fahreffizienz -- Kürzlich",
        "fr": "Efficacité énergétique -- Récente",
        "es": "Eficiencia de conducción -- Reciente",
        "zh-Hans": "行驶能效 -- 近期",
        "ja": "電費効率 -- 最近",
        "nb": "Kjøreeffektivitet -- Nylig",
        "th": "ประสิทธิภาพการขับขี่ -- ล่าสุด"
    },
    "Range (%@)": {
        "en": "Range (%1$@)",
        "de": "Reichweite (%1$@)",
        "fr": "Autonomie (%1$@)",
        "es": "Autonomía (%1$@)",
        "zh-Hans": "续航 (%1$@)",
        "ja": "航続距離 (%1$@)",
        "nb": "Rekkevidde (%1$@)",
        "th": "ระยะทาง (%1$@)"
    },
    "Trend: %.1f%%": {
        "en": "Trend: %1$.1f%%",
        "de": "Trend: %1$.1f%%",
        "fr": "Tendance : %1$.1f %%",
        "es": "Tendencia: %1$.1f%%",
        "zh-Hans": "趋势: %1$.1f%%",
        "ja": "傾向: %1$.1f%%",
        "nb": "Trend: %1$.1f %%",
        "th": "แนวโน้ม: %1$.1f%%"
    },
    "%.1f kWh • %@": {
        "en": "%1$.1f kWh • %2$@",
        "de": "%1$.1f kWh • %2$@",
        "fr": "%1$.1f kWh • %2$@",
        "es": "%1$.1f kWh • %2$@",
        "zh-Hans": "%1$.1f kWh • %2$@",
        "ja": "%1$.1f kWh • %2$@",
        "nb": "%1$.1f kWh • %2$@",
        "th": "%1$.1f kWh • %2$@"
    },
    "100% Nominal": {
        "en": "100% Nominal",
        "de": "100% Nennwert",
        "fr": "100 % Nominal",
        "es": "100% Nominal",
        "zh-Hans": "100% 标称",
        "ja": "100% 定格",
        "nb": "100 % nominell",
        "th": "100% พิกัดโรงงาน"
    }
}

def generate_catalog():
    source_path = "Sources/Localizable.xcstrings"
    
    # Load original catalog if exists to preserve any custom comments or metadata
    existing_meta = {}
    if os.path.exists(source_path):
        with open(source_path, "r", encoding="utf-8") as f:
            old_catalog = json.load(f)
            for k, v in old_catalog.get("strings", {}).items():
                existing_meta[k] = {
                    "comment": v.get("comment"),
                    "isCommentAutoGenerated": v.get("isCommentAutoGenerated"),
                }
    
    output_strings = {}
    target_languages = ["en", "de", "fr", "es", "zh-Hans", "ja", "nb", "th"]
    
    for key, trans in sorted(TRANSLATIONS.items()):
        entry = {}
        
        # Preserve or set comment
        comment = trans.get("comment") or (existing_meta.get(key, {}).get("comment"))
        if comment:
            entry["comment"] = comment
        if existing_meta.get(key, {}).get("isCommentAutoGenerated"):
            entry["isCommentAutoGenerated"] = True
            
        localizations = {}
        for lang in target_languages:
            val = trans.get(lang)
            if val is not None:
                localizations[lang] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": val
                    }
                }
        
        if localizations:
            entry["localizations"] = localizations
            
        output_strings[key] = entry
        
    catalog_data = {
        "sourceLanguage": "en",
        "strings": output_strings,
        "version": "1.1"
    }
    
    with open(source_path, "w", encoding="utf-8") as f:
        json.dump(catalog_data, f, ensure_ascii=False, indent=2)
        f.write("\n")
        
    print(f"Generated {len(output_strings)} keys in {source_path} for languages: {target_languages}")

if __name__ == "__main__":
    generate_catalog()

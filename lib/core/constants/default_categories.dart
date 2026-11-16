class DefaultCategories {
  static const List<Map<String, dynamic>> list = [
    {
      'name': 'Plastic Bottle / PET',
      'rate': 20.0,
      'icon': 'local_drink_rounded',
      'description': 'Water/soda bottles, PET & HDPE plastics',
      'recycling_steps': [
        'Empty all residual liquids completely and rinse with clean water.',
        'Remove plastic caps and separate loose tamper-evident neck rings.',
        'Crush and flatten bottles vertically to reduce storage volume by 75%.',
        'Keep transparent PET clear and separate from colored HDPE detergent containers.'
      ],
      'disposal_warning':
          'Never burn plastics. Open burning of PET and plastics releases carcinogenic dioxins, furans, and toxic particulate matter into the air.',
    },
    {
      'name': 'Aluminum Can & Tins',
      'rate': 35.0,
      'icon': 'inventory_2_rounded',
      'description': 'Beverage cans, tin cans, foil scrap',
      'recycling_steps': [
        'Drain sugary drinks and food sauces, then give a quick water rinse.',
        'Crush aluminum beverage cans flat for maximum transport and storage density.',
        'For food tins, remove paper labels and push sharp metal lids safely inside the can.',
        'Keep clean aluminum separate from bi-metal or rusty steel food tins.'
      ],
      'disposal_warning':
          'Wear protective gloves when handling cut tin edges. Never puncture, crush, or incinerate pressurized aerosol cans as they can violently explode.',
    },
    {
      'name': 'Paper/Cardboard',
      'rate': 10.0,
      'icon': 'description_rounded',
      'description': 'Cartons, corrugated boxes, newspapers & books',
      'recycling_steps': [
        'Peel off plastic packing tape, shipping pouches, styrofoam, and heavy staples.',
        'Break down and flatten all corrugated cardboard boxes completely.',
        'Stack newspapers, magazines, and flattened cartons into neat bundles tied with twine.',
        'Store in a dry location sheltered from rain and ground dampness.'
      ],
      'disposal_warning':
          'Do not include paper contaminated with food grease, pizza oils, wax coatings, or mold. Oil ruins paper fiber re-pulping and contaminates recycling batches.',
    },
    {
      'name': 'Iron & Steel',
      'rate': 28.0,
      'icon': 'hardware_rounded',
      'description': 'Scrap iron, rebar, steel frames & fixtures',
      'recycling_steps': [
        'Use a magnet to confirm ferrous metal (magnets will stick firmly to iron & steel).',
        'Knock off concrete, dirt, rubber gaskets, and non-metallic attachments.',
        'Sort heavy structural scrap, rebar, and cast iron separately from light sheet metal.',
        'Wear heavy-duty puncture-resistant work gloves and safety footwear during handling.'
      ],
      'disposal_warning':
          'Watch out for sharp metal burrs and tetanus risks from rusted edges. Never cut or scrap closed drums, fuel tanks, or gas cylinders without certified degassing.',
    },
    {
      'name': 'Copper & Wiring',
      'rate': 450.0,
      'icon': 'cable_rounded',
      'description': 'Stripped copper, electric wires & cables',
      'recycling_steps': [
        'Strip outer PVC/rubber insulation with wire strippers to expose Bare Bright #1 copper.',
        'Cut away brass fittings, connectors, soldered joints, and steel screw clamps.',
        'Separate thin insulated appliance cords and communication cables into lower-grade batches.',
        'Coil clean bare copper neatly for accurate grading and top scrap yard payout.'
      ],
      'disposal_warning':
          'NEVER burn off wire insulation to extract copper. Open burning releases deadly hydrogen chloride and dioxins, creates heavy soil pollution, and scrap yards strictly reject burnt copper.',
    },
    {
      'name': 'E-Waste & Circuitry',
      'rate': 120.0,
      'icon': 'memory_rounded',
      'description': 'Motherboards, PCBs, old phones & electronics',
      'recycling_steps': [
        'Eject and isolate lithium-ion or lead-acid batteries prior to electronic recycling.',
        'Perform a secure data wipe or remove internal SSDs/hard drives from computers and phones.',
        'Keep printed circuit boards, green motherboards, and server cards intact without snapping.',
        'Store e-waste indoors away from moisture to prevent hazardous heavy metals from oxidizing.'
      ],
      'disposal_warning':
          'Do not crush electronic components, smash CRT glass, or puncture swollen batteries. E-waste contains lead, cadmium, and mercury that leach into groundwater and can spark lithium thermal runaway fires.',
    },
    {
      'name': 'Glass Bottles',
      'rate': 4.0,
      'icon': 'liquor_rounded',
      'description': 'Glass jars, beverage containers & broken cullet',
      'recycling_steps': [
        'Empty all liquids and rinse food jars thoroughly with warm water.',
        'Remove metal crown caps, plastic lids, and wire cork cages.',
        'Sort bottles by glass color (Clear/Flint, Amber/Brown, and Emerald Green) if requested by your local scrap center.',
        'Place intact bottles into sturdy crates or boxes to avoid accidental shattering.'
      ],
      'disposal_warning':
          'Never mix Pyrex cookware, ceramics, mirrors, window glass, or light bulbs with container glass. These have incompatible melting temperatures and will ruin entire molten batches in glass furnaces.',
    },
  ];
}

-- V2: Seed destinations — 18 rows, 2-3 per category, realistic names

INSERT INTO destinations (name, country, description, price_per_night, image_url, category) VALUES

-- MOUNTAIN
('Manali', 'India',
 'A breathtaking hill station nestled in the Himalayas, perfect for skiing, trekking, and river rafting along the Beas River.',
 89.00, 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?w=800', 'MOUNTAIN'),

('Zermatt', 'Switzerland',
 'Iconic alpine village at the foot of the Matterhorn. World-class skiing, pristine trails, and car-free charm.',
 340.00, 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=800', 'MOUNTAIN'),

('Banff', 'Canada',
 'Turquoise glacial lakes, rugged Rocky Mountain peaks, and incredible wildlife make Banff a must-visit year-round.',
 210.00, 'https://images.unsplash.com/photo-1609349093414-b7a9fcfa6b3d?w=800', 'MOUNTAIN'),

-- BEACH
('Maldives Atolls', 'Maldives',
 'Overwater bungalows, crystal-clear lagoons, and some of the world''s best coral reefs for snorkelling and diving.',
 520.00, 'https://images.unsplash.com/photo-1512100356356-de1b84283e18?w=800', 'BEACH'),

('Goa', 'India',
 'Sun-drenched coastline fringed with palm trees, vibrant beach shacks, Portuguese-era architecture, and legendary nightlife.',
 65.00, 'https://images.unsplash.com/photo-1587922546307-776227941871?w=800', 'BEACH'),

('Phuket', 'Thailand',
 'Thailand''s largest island offers stunning beaches like Patong and Kata, vibrant markets, and easy access to the Phi Phi Islands.',
 95.00, 'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?w=800', 'BEACH'),

-- CITY
('Tokyo', 'Japan',
 'A mesmerising blend of ultramodern skyscrapers and traditional temples, world-leading cuisine, and 24-hour street life.',
 180.00, 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800', 'CITY'),

('Paris', 'France',
 'The City of Light: iconic landmarks, world-class museums, haute cuisine, and unmistakable romantic atmosphere.',
 220.00, 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800', 'CITY'),

('New York City', 'USA',
 'The city that never sleeps — from Times Square to Central Park, Broadway shows to rooftop bars, always something new.',
 280.00, 'https://images.unsplash.com/photo-1490644658840-3f2e3f8c5625?w=800', 'CITY'),

-- ADVENTURE
('Queenstown', 'New Zealand',
 'The adventure capital of the world: bungee jumping, skydiving, white-water rafting, and jaw-dropping fjord scenery.',
 175.00, 'https://images.unsplash.com/photo-1507699622108-4be3abd695ad?w=800', 'ADVENTURE'),

('Patagonia', 'Argentina',
 'Wild, wind-swept landscapes at the tip of South America — trekking Torres del Paine, glaciers, and condors overhead.',
 130.00, 'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=800', 'ADVENTURE'),

-- CULTURAL
('Kyoto', 'Japan',
 'Japan''s ancient capital: thousands of temples, traditional tea houses, geisha districts, and perfectly preserved shrines.',
 155.00, 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=800', 'CULTURAL'),

('Varanasi', 'India',
 'One of the world''s oldest living cities, on the banks of the Ganges — sacred ghats, ancient rituals, and timeless spirituality.',
 45.00, 'https://images.unsplash.com/photo-1561361058-c24e021c9916?w=800', 'CULTURAL'),

('Rome', 'Italy',
 'Walk through 2,500 years of history: the Colosseum, Vatican Museums, Trevi Fountain, and unparalleled Italian gastronomy.',
 195.00, 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=800', 'CULTURAL'),

-- WILDLIFE
('Serengeti', 'Tanzania',
 'Witness the Great Migration — millions of wildebeest and zebras crossing the savannah under a vast African sky.',
 380.00, 'https://images.unsplash.com/photo-1516426122078-c23e76319801?w=800', 'WILDLIFE'),

('Jim Corbett National Park', 'India',
 'India''s oldest national park — dense sal forests, the Ramganga river, and thrilling tiger safari opportunities.',
 110.00, 'https://images.unsplash.com/photo-1474511320723-9a56873867b5?w=800', 'WILDLIFE'),

-- HONEYMOON
('Santorini', 'Greece',
 'Iconic whitewashed cycladic villages perched on volcanic cliffs above the Aegean — the world''s most romantic sunset.',
 290.00, 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=800', 'HONEYMOON'),

('Bali', 'Indonesia',
 'Lush rice terraces, ancient Hindu temples, luxurious private villa resorts, and a deeply spiritual island culture.',
 120.00, 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800', 'HONEYMOON');

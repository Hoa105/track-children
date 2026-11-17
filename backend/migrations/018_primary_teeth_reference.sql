-- Seed the 20 primary teeth using two-digit FDI notation.
INSERT INTO health.tooth_references
    (code, name, jaw, side, typical_month_from, typical_month_to)
VALUES
 ('51','Răng cửa giữa hàm trên bên phải','upper','right',8,12),
 ('52','Răng cửa bên hàm trên bên phải','upper','right',9,13),
 ('53','Răng nanh hàm trên bên phải','upper','right',16,22),
 ('54','Răng hàm thứ nhất hàm trên bên phải','upper','right',13,19),
 ('55','Răng hàm thứ hai hàm trên bên phải','upper','right',25,33),
 ('61','Răng cửa giữa hàm trên bên trái','upper','left',8,12),
 ('62','Răng cửa bên hàm trên bên trái','upper','left',9,13),
 ('63','Răng nanh hàm trên bên trái','upper','left',16,22),
 ('64','Răng hàm thứ nhất hàm trên bên trái','upper','left',13,19),
 ('65','Răng hàm thứ hai hàm trên bên trái','upper','left',25,33),
 ('71','Răng cửa giữa hàm dưới bên trái','lower','left',6,10),
 ('72','Răng cửa bên hàm dưới bên trái','lower','left',10,16),
 ('73','Răng nanh hàm dưới bên trái','lower','left',17,23),
 ('74','Răng hàm thứ nhất hàm dưới bên trái','lower','left',14,18),
 ('75','Răng hàm thứ hai hàm dưới bên trái','lower','left',23,31),
 ('81','Răng cửa giữa hàm dưới bên phải','lower','right',6,10),
 ('82','Răng cửa bên hàm dưới bên phải','lower','right',10,16),
 ('83','Răng nanh hàm dưới bên phải','lower','right',17,23),
 ('84','Răng hàm thứ nhất hàm dưới bên phải','lower','right',14,18),
 ('85','Răng hàm thứ hai hàm dưới bên phải','lower','right',23,31)
ON CONFLICT (code) DO UPDATE SET
 name=EXCLUDED.name, jaw=EXCLUDED.jaw, side=EXCLUDED.side,
 typical_month_from=EXCLUDED.typical_month_from,
 typical_month_to=EXCLUDED.typical_month_to;

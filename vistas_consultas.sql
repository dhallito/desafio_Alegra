use DeliveryApp;

DROP VIEW perdida_descuento;
DROP VIEW obsequio_cliente;
DROP VIEW prioridad_medio_envio;
DROP VIEW venta_año;

-- 1 ¿Cuál ha sido el porcentaje de crecimiento de las ventas por año?
-- CREATE VIEW venta_año AS
WITH crecimiento(año, ventas_brutas, ventas_netas, productos_vendidos, ventas_unicas) AS (
	SELECT YEAR(v.fecha_venta) AS año, 
			sum(v.precio_unitario*v.cantidad) AS ventas_brutas, 
			sum(v.precio_unitario*v.cantidad*(1-d.descuento)) AS ventas_netas, 
			sum(v.cantidad) AS productos_vendidos, 
			count(v.id) AS ventas_unicas
	FROM venta v
	LEFT JOIN descuento d
	ON v.descuento_id = d.id
	GROUP BY YEAR(v.fecha_venta)
)
SELECT c.año, 
	c.ventas_brutas,
    c.ventas_netas,
    c.productos_vendidos,
    c.ventas_unicas,
    c.ventas_netas - c2.ventas_netas AS crecimiento_absoluto,
	100*(c.ventas_netas - c2.ventas_netas)/c2.ventas_netas AS crecimiento_porcentual	
FROM crecimiento c
LEFT JOIN crecimiento c2
ON c.año-1 = c2.año
ORDER BY c.año;

-- CREATE VIEW venta_año AS
-- SELECT YEAR(v.fecha_venta) AS año, 
-- 		sum(v.precio_unitario*v.cantidad) AS ventas_brutas, 
--         sum(v.precio_unitario*v.cantidad*(1-d.descuento)) AS ventas_netas, 
--         sum(v.cantidad) AS productos_vendidos, 
--         count(v.id) AS ventas_unicas
-- FROM venta v
-- LEFT JOIN descuento d
-- ON v.descuento_id = d.id
-- GROUP BY YEAR(v.fecha_venta);

-- 2 Medios de envío con mayor prioridad
CREATE VIEW prioridad_medio_envio AS
SELECT v.medio_envio,
	count(CASE WHEN v.prioridad IN ('High','Critical') THEN 1 ELSE NULL END) AS prioridad_high_critical,
	count(v.id) AS ventas_unicas, 
    sum(v.precio_unitario*v.cantidad) AS ventas_brutas, 
	sum(v.precio_unitario*v.cantidad*(1-d.descuento)) AS ventas_netas,
    count(v.id)*100/(SELECT count(v.id) FROM venta v GROUP BY v.provincia ORDER BY count(v.id) DESC LIMIT 1) AS ventas_unicas_porcentuales,
    sum(v.precio_unitario*v.cantidad)*100/(
		SELECT sum(v.precio_unitario*v.cantidad) 
        FROM venta v 
        GROUP BY v.provincia 
        ORDER BY sum(v.precio_unitario*v.cantidad) DESC LIMIT 1) AS ventas_brutas_porcentuales,
    sum(v.precio_unitario*v.cantidad*(1-d.descuento))*100/(
		SELECT sum(v.precio_unitario*v.cantidad*(1-d.descuento)) 
        FROM venta v 
        LEFT JOIN descuento d 
        ON v.descuento_id = d.id 
        GROUP BY v.provincia 
        ORDER BY sum(v.precio_unitario*v.cantidad*(1-d.descuento)) DESC LIMIT 1) AS ventas_netas_porcentuales,
    (SELECT v.provincia	FROM venta v GROUP BY v.provincia ORDER BY count(v.id) DESC LIMIT 1) AS provincia
FROM venta v
LEFT JOIN descuento d
ON v.descuento_id = d.id
LEFT JOIN (
	SELECT v.provincia, count(v.id)
	FROM venta v
    GROUP BY v.provincia
    ORDER BY count(v.id) DESC
    LIMIT 1) AS prov
ON v.provincia = prov.provincia
WHERE prov.provincia IS NOT NULL
GROUP BY v.medio_envio
ORDER BY prioridad_high_critical desc;

-- 3 Pérdidas por descuentos
CREATE VIEW perdida_descuento AS
SELECT 
	ventaM.segmento, 
	sum(ventaM.cantidad*ventaM.precio_unitario*d.descuento) AS perdidas_descuento, 
	sum(ventaM.cantidad*ventaM.precio_unitario*d.descuento)/sum(ventaM.cantidad*ventaM.precio_unitario) AS perdidas_descuento_porcentual, 
	count(ventaM.id) AS ventas_unicas
FROM 
	(SELECT v.id, v.cantidad, v.precio_unitario, v.descuento_id, v.segmento
	FROM venta v
	LEFT JOIN cliente c
	ON v.cliente_id = c.id
	WHERE c.genero = 'M' AND c.edad >= 30) ventaM
LEFT JOIN descuento d
ON ventaM.descuento_id = d.id
GROUP BY ventaM.segmento
ORDER BY ventas_unicas desc;

-- 4 Premios mejores clientes
CREATE VIEW obsequio_cliente AS
WITH premios(nombre, mayor_compra, ventas_unicas, ventas_netas) AS (
	SELECT 
		c.nombre,
		max(v.cantidad*v.precio_unitario) AS mayor_compra,
		count(v.id) AS ventas_unicas,
		sum(v.precio_unitario*v.cantidad*(1-d.descuento)) AS ventas_netas
	FROM venta v
	LEFT JOIN descuento d
	ON v.descuento_id = d.id
	LEFT JOIN cliente c
	ON v.cliente_id = c.id
	WHERE year(v.fecha_venta)=2012
	GROUP BY c.nombre
)
SELECT p.nombre, 
	p.mayor_compra, 
    p.ventas_unicas, 
    p.ventas_netas,
	CASE WHEN p.mayor_compra = (SELECT max(p.mayor_compra) FROM premios p) THEN 0.01 ELSE 0 END AS obsequio_A,
    CASE WHEN p.ventas_unicas = (SELECT max(p.ventas_unicas) FROM premios p) THEN 0.02 ELSE 0 END AS obsequio_B,
    CASE WHEN p2.nombre IS NOT NULL THEN 0.04 ELSE 0 END AS obsequio_C,
    ((CASE WHEN p.mayor_compra = (SELECT max(p.mayor_compra) FROM premios p) THEN 0.01 ELSE 0 END)+
    (CASE WHEN p.ventas_unicas = (SELECT max(p.ventas_unicas) FROM premios p) THEN 0.02 ELSE 0 END)+
    (CASE WHEN p2.nombre IS NOT NULL THEN 0.04 ELSE 0 END))*p.ventas_netas AS valor_bonus
FROM premios p
LEFT JOIN (
	SELECT p.ventas_netas, p.nombre
    FROM premios p 
    ORDER BY p.ventas_netas DESC 
    LIMIT 3) AS p2
ON p.nombre = p2.nombre
ORDER BY valor_bonus desc;
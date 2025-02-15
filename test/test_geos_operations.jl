function equivalent_to_wkt(geom::LibGEOS.AbstractGeometry, wkt::String)
    test_geom = readgeom(wkt)
    @test LibGEOS.equals(geom, test_geom)
end

function factcheck(f::Function, geom::String, expected::String)
    result = f(readgeom(geom))
    equivalent_to_wkt(result, expected)
end

function factcheck(f::Function, geom::String, expected::Bool)
    @test f(readgeom(geom)) == expected
end

function factcheck(f::Function, g1::String, g2::String, expected::String)
    result = f(readgeom(g1), readgeom(g2))
    equivalent_to_wkt(result, expected)
end

function factcheck(f::Function, g1::String, g2::String, expected::Bool)
    @test f(readgeom(g1), readgeom(g2)) == expected
    @test f(prepareGeom(readgeom(g1)), readgeom(g2)) == expected
end

@testset "GEOS operations" begin
    ls = LineString(Vector{Float64}[[8, 1], [9, 1], [9, 2], [8, 2]])
    pt = interpolate(ls, 2.5)
    @test GeoInterface.coordinates(pt) ≈ [8.5, 2.0] atol = 1e-5
    for (pt, dist, dest) in [
        (Point(10.0, 1.0), 1.0, Point(9.0, 1.0)),
        (Point(9.0, 1.0), 1.0, Point(9.0, 1.0)),
        (Point(10.0, 0.0), 1.0, Point(9.0, 1.0)),
        (Point(9.0, 2.0), 2.0, Point(9.0, 2.0)),
        (Point(8.7, 1.5), 1.5, Point(9.0, 1.5)),
    ]
        test_dist = project(ls, pt)
        @test test_dist ≈ dist atol = 1e-5
        @test equals(interpolate(ls, test_dist), dest)
    end

    # GEOSConvexHullTest
    input = readgeom(
        "MULTIPOINT (130 240, 130 240, 130 240, 570 240, 570 240, 570 240, 650 240)",
    )
    expected = readgeom("LINESTRING (130 240, 650 240)")
    output = convexhull(input)
    @test !isEmpty(output)
    @test writegeom(output) == writegeom(expected)

    # LibGEOS.delaunayTriangulationTest
    g1 = readgeom("POLYGON EMPTY")
    g2 = delaunayTriangulationEdges(g1)
    @test isEmpty(g1)
    @test isEmpty(g2)
    @test GeoInterface.geomtrait(g2) == MultiLineStringTrait()

    g1 = readgeom("POINT(0 0)")
    g2 = delaunayTriangulation(g1)
    @test isEmpty(g2)
    @test GeoInterface.geomtrait(g2) == GeometryCollectionTrait()

    g1 = readgeom("MULTIPOINT(0 0, 5 0, 10 0)")
    g2 = delaunayTriangulation(g1, 0.0)
    @test isEmpty(g2)
    @test GeoInterface.geomtrait(g2) == GeometryCollectionTrait()
    g2 = delaunayTriangulationEdges(g1, 0.0)
    equivalent_to_wkt(g2, "MULTILINESTRING ((5 0, 10 0), (0 0, 5 0))")

    g1 = readgeom("MULTIPOINT(0 0, 10 0, 10 10, 11 10)")
    g2 = delaunayTriangulationEdges(g1, 2.0)
    equivalent_to_wkt(g2, "MULTILINESTRING ((0 0, 10 10), (0 0, 10 0), (10 0, 10 10))")

    # LibGEOS.constrainedDelaunayTriangulationTest
    g1 = readgeom("POLYGON EMPTY")
    g2 = constrainedDelaunayTriangulation(g1)
    @test isEmpty(g1)
    @test isEmpty(g2)
    @test GeoInterface.geomtrait(g2) == GeometryCollectionTrait()

    g1 = readgeom("POINT(0 0)")
    g2 = constrainedDelaunayTriangulation(g1)
    @test isEmpty(g2)
    @test GeoInterface.geomtrait(g2) == GeometryCollectionTrait()

    g1 = readgeom("POLYGON ((10 10, 20 40, 90 90, 90 10, 10 10))")
    g2 = constrainedDelaunayTriangulation(g1)
    equivalent_to_wkt(
        g2,
        "GEOMETRYCOLLECTION (POLYGON ((10 10, 20 40, 90 10, 10 10)), POLYGON ((90 90, 20 40, 90 10, 90 90)))",
    )

    # GEOSDistanceTest
    g1 = readgeom("POINT(10 10)")
    g2 = readgeom("POINT(3 6)")
    @test distance(g1, g2) ≈ 8.06225774829855 atol = 1e-12

    # GEOSGeom_extractUniquePointsTest
    g1 = readgeom("POLYGON EMPTY")
    g2 = uniquePoints(g1)
    @test isEmpty(g2)

    g1 = readgeom("MULTIPOINT(0 0, 0 0, 1 1)")
    g2 = uniquePoints(g1)
    @test equals(g2, readgeom("MULTIPOINT(0 0, 1 1)"))
    @test GeoInterface.equals(g2, readgeom("MULTIPOINT(0 0, 1 1)"))

    g1 = readgeom(
        "GEOMETRYCOLLECTION(MULTIPOINT(0 0, 0 0, 1 1),LINESTRING(1 1, 2 2, 2 2, 0 0),POLYGON((5 5, 0 0, 0 2, 2 2, 5 5)))",
    )
    @test LibGEOS.equals(uniquePoints(g1), readgeom("MULTIPOINT(0 0, 1 1, 2 2, 5 5, 0 2)"))

    # GEOSGetCentroidTest
    test_centroid(geom::String, expected::String) = factcheck(centroid, geom, expected)
    test_centroid("POINT(10 0)", "POINT (10 0)")
    test_centroid("LINESTRING(0 0, 10 0)", "POINT (5 0)")
    test_centroid("POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))", "POINT (5 5)")
    test_centroid("LINESTRING EMPTY", "POINT EMPTY")

    # GEOSIntersectionTest
    test_intersection(g1::String, g2::String, expected::String) =
        factcheck(intersection, g1, g2, expected)
    test_intersection("POLYGON EMPTY", "POLYGON EMPTY", "GEOMETRYCOLLECTION EMPTY")
    test_intersection("POLYGON((1 1,1 5,5 5,5 1,1 1))", "POINT(2 2)", "POINT(2 2)")
    test_intersection(
        "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))",
        "POLYGON((-1 1,-1 2,2 2,2 1,-1 1))",
        "POLYGON ((0 1, 0 2, 2 2, 2 1, 0 1))",
    )
    test_intersection(
        "MULTIPOLYGON(((0 0,5 10,10 0,0 0),(1 1,1 2,2 2,2 1,1 1),(100 100,100 102,102 102,102 100,100 100)))",
        "POLYGON((0 1,0 2,10 2,10 1,0 1))",
        "GEOMETRYCOLLECTION (LINESTRING (1 2, 2 2), LINESTRING (2 1, 1 1), POLYGON ((0.5 1, 1 2, 1 1, 0.5 1)), POLYGON ((9 2, 9.5 1, 2 1, 2 2, 9 2)))",
    )

    # LineString_PointTest
    g1 = readgeom("LINESTRING(0 0, 5 5, 10 10)")
    @test !isClosed(g1)
    @test GeoInterface.geomtrait(g1) == LineStringTrait()
    @test numPoints(g1) == 3
    @test geomLength(g1) ≈ sqrt(100 + 100) atol = 1e-5
    @test GeoInterface.coordinates(startPoint(g1)) ≈ [0, 0] atol = 1e-5
    @test GeoInterface.coordinates(endPoint(g1)) ≈ [10, 10] atol = 1e-5

    # GEOSNearestPointsTest
    g1 = readgeom("POLYGON EMPTY")
    g2 = readgeom("POLYGON EMPTY")
    @test length(nearestPoints(g1, g2)) == 0

    g1 = readgeom("POLYGON((1 1,1 5,5 5,5 1,1 1))")
    g2 = readgeom("POLYGON((8 8, 9 9, 9 10, 8 8))")
    points = nearestPoints(g1, g2)
    @test length(points) == 2
    @test GeoInterface.coordinates(points[1])[1:2] == [5.0, 5.0]
    @test GeoInterface.coordinates(points[2])[1:2] == [8.0, 8.0]

    # GEOSNodeTest
    g1 = node(readgeom("LINESTRING(0 0, 10 10, 10 0, 0 10)"))
    LibGEOS.normalize!(g1)
    equivalent_to_wkt(
        g1,
        "MULTILINESTRING ((5 5, 10 0, 10 10, 5 5), (0 10, 5 5), (0 0, 5 5))",
    )

    g1 = node(readgeom("MULTILINESTRING((0 0, 2 0, 4 0),(5 0, 3 0, 1 0))"))
    LibGEOS.normalize!(g1)
    equivalent_to_wkt(
        g1,
        "MULTILINESTRING ((4 0, 5 0), (3 0, 4 0), (2 0, 3 0), (1 0, 2 0), (0 0, 1 0))",
    )

    g1 = node(readgeom("MULTILINESTRING((0 0, 2 0, 4 0),(0 0, 2 0, 4 0))"))
    LibGEOS.normalize!(g1)
    equivalent_to_wkt(g1, "MULTILINESTRING ((2 0, 4 0), (0 0, 2 0))")

    # GEOSPointOnSurfaceTest
    test_pointonsurface(geom::String, expected::String) =
        factcheck(pointOnSurface, geom, expected)
    test_pointonsurface("POINT(10 0)", "POINT (10 0)")
    test_pointonsurface("LINESTRING(0 0, 5 0, 10 0)", "POINT (5 0)")
    test_pointonsurface("POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))", "POINT (5 5)")
    test_pointonsurface("LINESTRING EMPTY", "POINT EMPTY")
    test_pointonsurface("LINESTRING(0 0, 0 0)", "POINT (0 0)")

    g1 = readgeom("""POLYGON((
                  56.528666666700 25.2101666667,
                  56.529000000000 25.2105000000,
                  56.528833333300 25.2103333333,
                  56.528666666700 25.2101666667))""")
    @test GeoInterface.coordinates(pointOnSurface(g1)) ≈ [56.5286666667, 25.2101666667] atol =
        1e-5

    # GEOSSharedPathsTest
    factcheck(
        sharedPaths,
        "LINESTRING (-30 -20, 50 60, 50 70, 50 0)",
        "LINESTRING (-29 -20, 50 60, 50 70, 51 0)",
        "GEOMETRYCOLLECTION (MULTILINESTRING ((50 60, 50 70)), MULTILINESTRING EMPTY)",
    )

    # GEOSSimplifyTest
    g1 = readgeom("POLYGON EMPTY")
    @test isEmpty(g1)
    g2 = simplify(g1, 43.2)
    @test isEmpty(g2)
    g1 = readgeom("""POLYGON((
                  56.528666666700 25.2101666667,
                  56.529000000000 25.2105000000,
                  56.528833333300 25.2103333333,
                  56.528666666700 25.2101666667))""")
    equivalent_to_wkt(simplify(g1, 0.0), "POLYGON EMPTY")
    @test equals(g1, topologyPreserveSimplify(g1, 43.2))

    # GEOSSnapTest
    function test_snap(g1::String, g2::String, expected::String, tol::Float64 = 0.0)
        equivalent_to_wkt(snap(readgeom(g1), readgeom(g2), tol), expected)
    end
    test_snap(
        "POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0))",
        "POINT(0.5 0)",
        "POLYGON ((0.5 0, 10 0, 10 10, 0 10, 0.5 0))",
        1.0,
    )
    test_snap(
        "LINESTRING (-30 -20, 50 60, 50 0)",
        "LINESTRING (-29 -20, 40 60, 51 0)",
        "LINESTRING (-29 -20, 50 60, 51 0)",
        2.0,
    )
    test_snap(
        "LINESTRING (-20 -20, 50 50, 100 100)",
        "LINESTRING (-10 -9, 40 20, 80 79)",
        "LINESTRING (-20 -20, -10 -9, 50 50, 80 79, 100 100)",
        2.0,
    )
    test_snap("LINESTRING(0 0, 10 0)", "LINESTRING(0 0, 9 0)", "LINESTRING(0 0, 9 0)", 2.0)
    test_snap(
        "LINESTRING(0 0, 10 0)",
        "LINESTRING(0 0, 9 0, 10 0, 11 0)",
        "LINESTRING(0 0, 9 0, 10 0, 11 0)",
        2.0,
    )
    test_snap(
        "LINESTRING(0 3,4 1,0 1)",
        "MULTIPOINT(5 0,4 1)",
        "LINESTRING (0 3, 4 1, 5 0, 0 1)",
        2.0,
    )
    test_snap(
        "LINESTRING(0 3,4 1,0 1)",
        "MULTIPOINT(4 1,5 0)",
        "LINESTRING (0 3, 4 1, 5 0, 0 1)",
        2.0,
    )
    test_snap(
        "LINESTRING(0 0,10 0,10 10,0 10,0 0)",
        "MULTIPOINT(0 0,-1 0)",
        "LINESTRING (-1 0, 0 0, 10 0, 10 10, 0 10, -1 0)",
        3.0,
    )
    test_snap(
        "LINESTRING(0 2,5 2,9 2,5 0)",
        "POINT(5 0)",
        "LINESTRING (0 2, 5 2, 9 2, 5 0)",
        3.0,
    )
    test_snap(
        "LINESTRING(-71.1317 42.2511,-71.1317 42.2509)",
        "MULTIPOINT(-71.1261 42.2703,-71.1257 42.2703,-71.1261 42.2702)",
        "LINESTRING (-71.1257 42.2703, -71.1261 42.2703, -71.1261 42.2702, -71.1317 42.2509)",
        0.5,
    )

    # GEOSUnaryUnionTest
    test_unaryunion(geom::String, expected::String) = factcheck(unaryUnion, geom, expected)
    test_unaryunion("POINT EMPTY", "POINT EMPTY")
    test_unaryunion("POINT (6 3)", "POINT (6 3)")
    test_unaryunion("POINT (4 5 6)", "POINT Z (4 5 6)")
    test_unaryunion("MULTIPOINT (4 5, 6 7, 4 5, 6 5, 6 7)", "MULTIPOINT (4 5, 6 5, 6 7)")
    test_unaryunion(
        "GEOMETRYCOLLECTION (POINT(4 5), MULTIPOINT(6 7, 6 5, 6 7), LINESTRING(0 5, 10 5), LINESTRING(4 -10, 4 10))",
        "GEOMETRYCOLLECTION (POINT (6 7), LINESTRING (0 5, 4 5), LINESTRING (4 5, 10 5), LINESTRING (4 -10, 4 5), LINESTRING (4 5, 4 10))",
    )
    test_unaryunion(
        "GEOMETRYCOLLECTION (POINT(4 5), MULTIPOINT(6 7, 6 5, 6 7), POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(5 6, 7 6, 7 8, 5 8, 5 6)))",
        "GEOMETRYCOLLECTION (POINT (6 7), POLYGON ((0 0, 10 0, 10 10, 0 10, 0 0), (5 6, 7 6, 7 8, 5 8, 5 6)))",
    )
    test_unaryunion(
        "GEOMETRYCOLLECTION (MULTILINESTRING((5 7, 12 7), (4 5, 6 5), (5.5 7.5, 6.5 7.5)), POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(5 6, 7 6, 7 8, 5 8, 5 6)))",
        "GEOMETRYCOLLECTION (LINESTRING (5 7, 7 7), LINESTRING (10 7, 12 7), LINESTRING (5.5 7.5, 6.5 7.5), POLYGON ((10 7, 10 0, 0 0, 0 10, 10 10, 10 7), (5 6, 7 6, 7 7, 7 8, 5 8, 5 7, 5 6)))",
    )
    test_unaryunion(
        "GEOMETRYCOLLECTION (MULTILINESTRING((5 7, 12 7), (4 5, 6 5), (5.5 7.5, 6.5 7.5)), POLYGON((0 0, 10 0, 10 10, 0 10, 0 0),(5 6, 7 6, 7 8, 5 8, 5 6)), MULTIPOINT(6 6.5, 6 1, 12 2, 6 1))",
        "GEOMETRYCOLLECTION (POINT (6 6.5), POINT (12 2), LINESTRING (5 7, 7 7), LINESTRING (10 7, 12 7), LINESTRING (5.5 7.5, 6.5 7.5), POLYGON ((10 7, 10 0, 0 0, 0 10, 10 10, 10 7), (5 6, 7 6, 7 7, 7 8, 5 8, 5 7, 5 6)))",
    )

    for (g1, g2, testvalue) in (
        ("POLYGON EMPTY", "POLYGON EMPTY", false),
        ("POLYGON((1 1,1 5,5 5,5 1,1 1))", "POINT(2 2)", false),
        ("POINT(2 2)", "POLYGON((1 1,1 5,5 5,5 1,1 1))", true),
        (
            "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))",
            "POLYGON((1 1,1 2,2 2,2 1,1 1))",
            false,
        ),
        (
            "POLYGON((1 1,1 2,2 2,2 1,1 1))",
            "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))",
            true,
        ),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 200 201, 300 300)", false),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 200 200, 300 300)", false),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 300 100)", false),
    )
        for f in (within, coveredby)
            factcheck(f, g1, g2, testvalue)
        end
        for f in (contains, covers)
            factcheck(f, g2, g1, testvalue)
        end
    end

    for (g1, g2, testvalue) in (
        ("POLYGON EMPTY", "POLYGON EMPTY", false),
        ("POLYGON((1 1,1 5,5 5,5 1,1 1))", "POINT(2 2)", true),
        ("POINT(2 2)", "POLYGON((1 1,1 5,5 5,5 1,1 1))", true),
        (
            "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))",
            "POLYGON((1 1,1 2,2 2,2 1,1 1))",
            true,
        ),
        (
            "POLYGON((1 1,1 2,2 2,2 1,1 1))",
            "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))",
            true,
        ),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 200 201, 300 300)", false),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 200 200, 300 300)", true),
        ("LINESTRING (100 200, 300 200)", "LINESTRING (100 300, 300 100)", true),
    )
        factcheck(intersects, g1, g2, testvalue)
        factcheck(disjoint, g1, g2, !testvalue)
    end

    # GEOSisClosedTest
    @test !isClosed(readgeom("LINESTRING(0 0, 1 0, 1 1)"))
    @test isClosed(readgeom("LINESTRING(0 0, 0 1, 1 1, 0 0)"))

    # -----
    # Geometry info
    # -----

    @testset "Polygon ring(s)" begin
        poly = readgeom(
            "POLYGON ((35 10, 45 45, 15 40, 10 20, 35 10),(20 30, 35 35, 30 20, 20 30))",
        )
        @test LibGEOS.getCoordinates(LibGEOS.getCoordSeq(exteriorRing(poly).ptr)) ==
              Vector{Float64}[[35, 10], [45, 45], [15, 40], [10, 20], [35, 10]]
        @test length(interiorRings(poly)) == 1
        @test LibGEOS.getCoordinates(LibGEOS.getCoordSeq(interiorRing(poly, 1).ptr)) ==
              Vector{Float64}[[20, 30], [35, 35], [30, 20], [20, 30]]
        @test_throws ErrorException interiorRing(poly, 0)
        @test_throws ErrorException interiorRing(poly, 2)
    end

    @testset "numGeometries" begin
        @test numGeometries(readgeom("POINT(2 2)")) == 1
        @test numGeometries(readgeom("MULTIPOINT(0 0, 5 0, 10 0)")) == 3
        @test numGeometries(readgeom("LINESTRING(0 0, 0 1, 1 1, 0 0)")) == 1
        @test numGeometries(
            readgeom("MULTILINESTRING ((5 5, 10 0, 10 10, 5 5), (0 10, 5 5), (0 0, 5 5))"),
        ) == 3
        @test numGeometries(readgeom("POLYGON((1 1,1 5,5 5,5 1,1 1))")) == 1
        # Polygon with a hole
        @test numGeometries(
            readgeom(
                "POLYGON ((35 10, 45 45, 15 40, 10 20, 35 10),(20 30, 35 35, 30 20, 20 30))",
            ),
        ) == 1
        @test numGeometries(
            readgeom(
                "MULTIPOLYGON (((30 20, 45 40, 10 40, 30 20)), ((15 5, 40 10, 10 20, 5 10, 15 5)))",
            ),
        ) == 2
        # MultiPolygon with holes
        @test numGeometries(
            readgeom(
                "MULTIPOLYGON (((40 40, 20 45, 45 30, 40 40)),((20 35, 10 30, 10 10, 30 5, 45 20, 20 35),(30 20, 20 15, 20 25, 30 20)))",
            ),
        ) == 2
        @test numGeometries(
            readgeom(
                "GEOMETRYCOLLECTION (POINT (40 10), LINESTRING (10 10, 20 20, 10 40), POLYGON ((40 40, 20 45, 45 30, 40 40)))",
            ),
        ) == 3
    end

    # Buffer should return Polygon or MultiPolygon
    @test buffer(MultiPoint([[1.0, 1.0], [2.0, 2.0], [2.0, 0.0]]), 0.1) isa
          LibGEOS.MultiPolygon
    @test buffer(MultiPoint([[1.0, 1.0], [2.0, 2.0], [2.0, 0.0]]), 10) isa LibGEOS.Polygon
    @test GeoInterface.buffer(MultiPoint([[1.0, 1.0], [2.0, 2.0], [2.0, 0.0]]), 10) isa
          LibGEOS.Polygon

    # bufferWithStyle
    g1 = bufferWithStyle(
        readgeom("LINESTRING(0 0,0 1,1 1)"),
        0.1,
        endCapStyle = LibGEOS.GEOSBUF_CAP_FLAT,
        joinStyle = LibGEOS.GEOSBUF_JOIN_BEVEL,
    )
    g2 = readgeom(
        "POLYGON((-0.1 0.0,-0.1 1.0,0.0 1.1,1.0 1.1,1.0 0.9,0.1 0.9,0.1 0.0,-0.1 0.0))",
    )
    @test equals(g1, g2)
    @test GeoInterface.equals(g1, g2)

    g1 = bufferWithStyle(
        readgeom("LINESTRING(0 0,0 1,1 1)"),
        0.1,
        endCapStyle = LibGEOS.GEOSBUF_CAP_SQUARE,
        joinStyle = LibGEOS.GEOSBUF_JOIN_MITRE,
    )
    g2 =
        readgeom("POLYGON((-0.1 -0.1,-0.1 1.1,1.1 1.1,1.1 0.9,0.1 0.9,0.1 -0.1,-0.1 -0.1))")
    @test equals(g1, g2)

    g1 = bufferWithStyle(
        readgeom("POLYGON((-1 -1,1 -1,1 1,-1 1,-1 -1))"),
        0.2,
        joinStyle = LibGEOS.GEOSBUF_JOIN_MITRE,
    )
    g2 = readgeom("POLYGON((-1.2 1.2,1.2 1.2,1.2 -1.2,-1.2 -1.2,-1.2 1.2))")
    @test equals(g1, g2)

    @testset "getXMin et al." begin
        # taken from https://github.com/libgeos/geos/blob/main/tests/unit/capi/GEOSGeom_extentTest.cpp
        g = readgeom(("LINESTRING (3 8, -12 -4)"))
        @test LibGEOS.getXMin(g) == -12
        @test LibGEOS.getXMax(g) == 3
        @test LibGEOS.getYMin(g) == -4
        @test LibGEOS.getYMax(g) == 8
        g = readgeom("POLYGON EMPTY")
        @test (@test_throws ErrorException LibGEOS.getXMin(g) == 0).value.msg ==
              "LibGEOS: Error in GEOSGeom_getXMin_r"
        @test (@test_throws ErrorException LibGEOS.getXMax(g) == 0).value.msg ==
              "LibGEOS: Error in GEOSGeom_getXMax_r"
        @test (@test_throws ErrorException LibGEOS.getYMin(g) == 0).value.msg ==
              "LibGEOS: Error in GEOSGeom_getYMin_r"
        @test (@test_throws ErrorException LibGEOS.getYMax(g) == 0).value.msg ==
              "LibGEOS: Error in GEOSGeom_getYMax_r"
    end

    @testset "getGeometry/getGeometries" begin
        @test writegeom(getGeometry(readgeom("POLYGON EMPTY"), 1)) == "POLYGON EMPTY"
        @test writegeom.(getGeometries(readgeom("POLYGON EMPTY"))) == ["POLYGON EMPTY"]

        multipoint = readgeom("MULTIPOINT (4 5, 6 7, 4 5, 6 5, 9 10)")
        @test writegeom(getGeometry(multipoint, 1)) == "POINT (4 5)"
        @test writegeom(getGeometry(multipoint, 2)) == "POINT (6 7)"
        @test writegeom(getGeometry(multipoint, 5)) == "POINT (9 10)"
        @test (@test_throws ErrorException getGeometry(multipoint, 7)).value.msg ==
              "GEOSGetGeometryN: 5 sub-geometries in geom, therefore n should be in 1:5"
        @test writegeom.(getGeometries(multipoint)) ==
              ["POINT (4 5)", "POINT (6 7)", "POINT (4 5)", "POINT (6 5)", "POINT (9 10)"]

        multilinestring =
            readgeom("MULTILINESTRING((5 7, 12 7), (4 5, 6 5), (5.5 7.5, 6.5 7.5))")
        @test writegeom(getGeometry(multilinestring, 1)) == "LINESTRING (5 7, 12 7)"
        @test writegeom(getGeometry(multilinestring, 2)) == "LINESTRING (4 5, 6 5)"
        @test writegeom(getGeometry(multilinestring, 3)) == "LINESTRING (5.5 7.5, 6.5 7.5)"
        @test writegeom.(getGeometries(multilinestring)) == [
            "LINESTRING (5 7, 12 7)",
            "LINESTRING (4 5, 6 5)",
            "LINESTRING (5.5 7.5, 6.5 7.5)",
        ]

        multipolygon = readgeom(
            "MULTIPOLYGON (((40 40, 20 45, 45 30, 40 40)), ((20 35, 10 30, 10 10, 30 5, 45 20, 20 35), (30 20, 20 15, 20 25, 30 20)))",
        )
        @test writegeom(getGeometry(multipolygon, 1)) ==
              "POLYGON ((40 40, 20 45, 45 30, 40 40))"
        @test writegeom(getGeometry(multipolygon, 2)) ==
              "POLYGON ((20 35, 10 30, 10 10, 30 5, 45 20, 20 35), (30 20, 20 15, 20 25, 30 20))"
        @test writegeom.(getGeometries(multipolygon)) == [
            "POLYGON ((40 40, 20 45, 45 30, 40 40))",
            "POLYGON ((20 35, 10 30, 10 10, 30 5, 45 20, 20 35), (30 20, 20 15, 20 25, 30 20))",
        ]

        geomcollection = readgeom(
            "GEOMETRYCOLLECTION (POINT (40 10), LINESTRING (10 10, 20 20, 10 40), POLYGON ((40 40, 20 45, 45 30, 40 40)))",
        )
        @test writegeom(getGeometry(geomcollection, 1)) == "POINT (40 10)"
        @test writegeom(getGeometry(geomcollection, 2)) ==
              "LINESTRING (10 10, 20 20, 10 40)"
        @test writegeom(getGeometry(geomcollection, 3)) ==
              "POLYGON ((40 40, 20 45, 45 30, 40 40))"
        @test writegeom.(getGeometries(geomcollection)) == [
            "POINT (40 10)",
            "LINESTRING (10 10, 20 20, 10 40)",
            "POLYGON ((40 40, 20 45, 45 30, 40 40))",
        ]
    end
end

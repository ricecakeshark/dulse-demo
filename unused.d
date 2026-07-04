module unused;

// Mesh, Geometry
/+
object_geometry.vertices = [
	VertexPNU(Vec3(-0.5f, -0.5f, 0.0f), Vec3(-0.5f, -0.5f, 0f), Vec2(0.0f, 0.0f,),),
	VertexPNU(Vec3(+0.5f, -0.5f, 0.0f,), Vec3(+0.5f, -0.5f, 0f), Vec2(1.0f, 0.0f,),),
	VertexPNU(Vec3(0.5f, +0.5f, 0.0f,), Vec3(+0.5f, +0.5f, 0f), Vec2(1.0f, 1.0f,),),
	VertexPNU(Vec3(-0.5f, +0.5f, 0.0f,), Vec3(-0.5f, +0.5f, 0f), Vec2(0.0f, 1.0f,),),
];
object_geometry.indices = [0, 1, 2, 0, 2, 3];
object_mesh.initialize(VertexPNU.sizeof * 4, uint.sizeof * 6);
object_mesh.set([object_geometry,]);
+/
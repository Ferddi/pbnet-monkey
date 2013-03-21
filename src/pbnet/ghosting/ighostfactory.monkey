
Strict

Import pbnet

' Factory for creating entities based on the prototype string passed during
' ghost creation.
Interface IGhostFactory

	' Make an Object instance using the specified prototype name, And
	' Return a reference To the Ghost that controls it.
	Method MakeGhost:Ghost(prototypeName:String, nr:NetRoot)

End Interface

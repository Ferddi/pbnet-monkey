
Strict

Import pbnet

Class NetError Extends Throwable

	Field str:String

	Method New(s:String)

		str = s
		Print s

	End Method
	
	Method ToString:String()
	
		Return str
		
	End Method

End Class

Class EOFError Extends Throwable

	Field str:String

	Method New(s:String)
	
		str = s
		'Print s
	
	End Method

	Method ToString:String()
	
		Return str
		
	End Method

End Class

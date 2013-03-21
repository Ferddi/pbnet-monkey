
Import pbnet

Class CircleEvent Extends GenericNetEvent

	Field x:Int
	Field y:Int

	'Field onCircleCallback:Function = Null

	Method New(nr:NetRoot)

		Super.New(nr, "circle")
		
		RegisterField("x")
		RegisterField("y")

		'Print "CircleEvent.New"

	End Method
      
	Method SetProperty:Void(fieldName:String, value:Object)

		Select fieldName
		
		Case "x"
			x = UnboxInt(value)
			
		Case "y"
			y = UnboxInt(value)
			
		End Select
	
	End Method

	Method GetProperty:Object(fieldName:String)

		Select fieldName
		
		Case "x"
			Return BoxInt(x)
		
		Case "y"
			Return BoxInt(y)
			
		End Select
		
		Return Null

	End Method

	Method Process:Void(conn:EventConnection)

		'If onCircleCallback <> Null
		'	onCircleCallback(this)
		'End If

	End Method

End Class
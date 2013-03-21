
Import pbnet

Class CircleEntity Extends IEntity

	Field x:Float
	Field y:Float
	
	Field goalX:Int
	Field goalY:Int

	Method New(nr:NetRoot)
	
		Super.New(nr)

		x = 0
		y = 0
		
		goalX = 0
		goalY = 0
	
	End Method

	Method SetProperty:Void(pr:String, netValue:Object)

		'Print "ClientCircle SetProperty PropertyReference: " + pr
		
		Select pr
		
		Case "@Mover.goalPosition.x"
			goalX = UnboxInt(netValue)
			'Print "goalX: " + goalX

		Case "@Mover.goalPosition.y"
			goalY = UnboxInt(netValue)
			'Print "goalY: " + goalY

		Case "@Mover.position.x"
			x = UnboxInt(netValue)

		Case "@Mover.position.y"
			y = UnboxInt(netValue)
		
		End Select

	End Method
	
	Method GetProperty:Object(pr:String)
	
		'Print "ServerCircle GetProperty PropertyReference: " + pr
	
		Select pr
		
		Case "@Mover.goalPosition.x"
			Return BoxInt(goalX)
			'Print "goalX: " + goalX

		Case "@Mover.goalPosition.y"
			Return BoxInt(goalY)
			'Print "goalY: " + goalY

		Case "@Mover.position.x"
			Return BoxInt(x)

		Case "@Mover.position.y"
			Return BoxInt(y)
		
		End Select

		Return Null
	
	End Method

End Class

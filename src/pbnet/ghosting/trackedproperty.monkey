
Strict

Import pbnet

' Map a Property on an IPropertyBag To a Field in our protocol/NetRoot.
Class TrackedProperty

	' Only set this Property For the first network update. Useful For handling
	' fields that you otherwise To interpolate.
	Field initialUpdateOnly:Bool
      
	' Property that is tracked.
	Field propRef:String
      
	' Field on the protocol that is associated with the tracked Property. Must
	' have a compatible type.
	Field protocolField:String
      
	' Last value we saw in the tracked Property. Used To detect changes And
	' update dirty state.
	Field lastValue:Object
	
	Method New(iuo:Bool, pr:String, pf:String)
	
		initialUpdateOnly = iuo
		propRef = pr
		protocolField = pf
	
	End Method

End Class

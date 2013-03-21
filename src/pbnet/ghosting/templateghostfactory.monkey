
Strict

Import pbnet

' In monkey version TemplateGhostFactory will be extended and MakeGhost will be program specific.

' Ghost Factory that uses the TemplateManager To manufactore ghost instances.
Class TemplateGhostFactory Implements IGhostFactory

	' Allow us To specify a specific TemplateManager To use, instead
	' of the Global instance.
	'Field overrideTemplateManager:TemplateManager = Null
      
	Method MakeGhost:Ghost(prototypeName:String, nr:NetRoot)

		'Local tm:TemplateManager = overrideTemplateManager;
		'If Not tm
			Print "TODO - need to instantiate templatemanager?"
			'tm = PBE.templateManager;
		'End If
         
		' Try instantiating the specified template.
		'Local entity:IEntity = tm.InstantiateEntity(prototypeName);
		'If Not entity
		'	Return Null;
		'End If
         
		' See If it has a ghost component on it.
		'Local entityGhostComponent:GhostComponent = GhostComponent(entity.LookupComponentByType("GhostComponent"))
		'If Not entityGhostComponent
		'	entity.Destroy();
		'	Return Null;
		'End If
         
		' Great, so get the ghost off it And Return that.
		'Return entityGhostComponent.ghostInstance;
		
		Return Null

	End Method

End Class

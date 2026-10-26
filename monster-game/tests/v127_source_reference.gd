extends HordeCosmetics

# Original source with the approved silhouette and the same animation clock.
# No accessory or source-cut mesh participates in this reference image.
func draw_item(_canvas:Node2D,_id:String,_f:Dictionary,_root:Transform2D,_tint:Color,_front:bool=false) -> void:pass
func draw_skull(_canvas:Node2D,_f:Dictionary,_root:Transform2D,_tint:Color) -> void:pass
func draw_source(_canvas:Node2D,_key:String,_cut:String,_transform:Transform2D,_tint:Color) -> void:pass

extends BattleAction
class_name ItemAction

var item_name: String

func execute():
	print(actor.data.name, "uses item:", item_name)

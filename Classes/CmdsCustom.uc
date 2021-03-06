class CmdsCustom extends Cmds;


var() config int nConfigFakes;
var() config int nReservedSlots;


function PostBeginPlay()
{
	ReservedPlayerSlots = Clamp(nReservedSlots,1,32);
	nFakes = Clamp(nConfigFakes,0,20);

	Super.PostBeginPlay();
}


function EditConfigSlots(PlayerController pc, string mod)
{
  local int slots;

  slots = Clamp(Int(mod), 1, 32);
  
  nReservedSlots = slots;
  SaveConfig();
  SendMessage(pc, "%gConfig Reserved Player Slots %ware changed to %b"$slots);
}


function EditConfigFakes(PlayerController pc, string mod)
{
  local int faked;

  faked = Clamp(Int(mod), 0, 20);

  nConfigFakes = faked;
  SaveConfig();
  SendMessage(pc, "%gConfig Faked Players %ware changed to - %b"$faked);
}


static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting("Cmds", "nReservedSlots", "Reserved Player Slots", 0, 2, "Text", "6;1:32", "", False, False);
	PlayInfo.AddSetting("Cmds", "nConfigFakes", "Faked Players", 0, 2, "Text", "6;0:20", "", False, False);
}


static function string GetDescriptionText(string s)
{
	switch (s)
	{
		case "nConfigFakes":
			return "Forced Faked Players";
		case "nReservedSlots":
			return "Reserved Player Slots";
	}

	return Super.GetDescriptionText(s);
}


static function string GetDisplayText(string PropName)
{
	switch (PropName)
	{
		case "nConfigFakes":
			return "Forced Faked Players";
		case "nReservedSlots":
			return "Reserved Player Slots";
	}

	return "Null";
}

defaultproperties
{
     nConfigFakes=0
     nReservedSlots=6
     bUseReservedSlots=True
     FriendlyName="CmdsCustom"
     Description="CmdsCustomCFG."
}

var patreons_levels = 2;
var patreons_game_perks = {
"patreon_perk_mp_regen_t1": 1,//
"patreon_perk_mp_regen_t2": 2,//
"patreon_perk_hp_regen_t1": 1,//
"patreon_perk_hp_regen_t2": 2,//
"patreon_perk_bonus_movespeed_t1": 1,//
"patreon_perk_bonus_movespeed_t2": 2,//
"patreon_perk_bonus_agi_t1": 1,//
"patreon_perk_bonus_agi_t2": 2,//
"patreon_perk_bonus_str_t1": 1,//
"patreon_perk_bonus_str_t2": 2,//
"patreon_perk_bonus_int_t1": 1,//
"patreon_perk_bonus_int_t2": 2,//
"patreon_perk_bonus_all_stats_t1": 1,//
"patreon_perk_bonus_all_stats_t2": 2,//
"patreon_perk_attack_range_t1": 1,
"patreon_perk_attack_range_t2": 2,
"patreon_perk_bonus_hp_pct_t1": 1,
"patreon_perk_bonus_hp_pct_t2": 2,
"patreon_perk_cast_range_t1": 1,
"patreon_perk_cast_range_t2": 2,
"patreon_perk_cooldown_reduction_t1": 1,
"patreon_perk_cooldown_reduction_t2": 2,
"patreon_perk_damage_t1": 1,
"patreon_perk_damage_t2": 2,
"patreon_perk_evasion_t1": 1,
"patreon_perk_evasion_t2": 2,
"patreon_perk_lifesteal_t1": 1,
"patreon_perk_lifesteal_t2": 2,
"patreon_perk_mag_resist_t1": 1,
"patreon_perk_mag_resist_t2": 2,
"patreon_perk_spell_amp_t1": 1,
"patreon_perk_spell_amp_t2": 2,
"patreon_perk_spell_lifesteal_t1": 1,
"patreon_perk_spell_lifesteal_t2": 2,
};

var patreons_game_perks_have_only_low_tier = {
	//"patreon_perk_bonus_agi_10": true,
}

var patreonLevel = 0;

function print(val){
	$.Msg(val);
}

function SetPlayerPatreonLevel(data){
	patreonLevel = data.patreonLevel;
}

function HidePatreonsGamePerksHint(){
	var settingsButton = $("#SetPatreonGamePerkButton")
	$.DispatchEvent( 'DOTAHideTextTooltip', settingsButton);
	settingsButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/patreon_button_setting_no_glow.png")
}

function ShowPatreonsGamePerksHint(){
	var settingsButton = $("#SetPatreonGamePerkButton")
	$.DispatchEvent( 'DOTAShowTextTooltip', settingsButton, $.Localize("#patreonperktooltip_hint"));
	settingsButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/patreon_button_setting_glow.png")
}

function ShowPatreonsGamePerks(){
	var perksPanel = $("#PatreonsGamePerkMenu");
	var perksPanelClose = $("#ClosePatreonsPerks");
	perksPanel.visible = true;
	perksPanelClose.visible = true;
}

function HidePatreonsGamePerks(){
	var perksPanel = $("#PatreonsGamePerkMenu");
	var perksPanelClose = $("#ClosePatreonsPerks");
	perksPanel.visible = false;
	perksPanelClose.visible = false;
}

function SetPatreonsPerkButtonAction(panel, perkName){
	panel.SetPanelEvent( "onactivate", function() {
		var settingPerksButton = $("#SetPatreonGamePerkButton")

		settingPerksButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/icons/"+perkName+".png")
		GameEvents.SendCustomGameEventToServer( "set_patreon_game_perk", {
			newPerkName: perkName
		} )
		settingPerksButton.SetPanelEvent( "onmouseover", function() {
			$.DispatchEvent( 'DOTAShowTextTooltip', settingPerksButton, $.Localize(perkName+"_tooltip"));
		} )
		settingPerksButton.SetPanelEvent( "onmouseout", function() {
			$.DispatchEvent( 'DOTAHideTextTooltip', settingPerksButton);
		} )
		settingPerksButton.SetPanelEvent( "onactivate", function() {} )
		HidePatreonsGamePerks()
	} )

	panel.SetPanelEvent( "onmouseover", function() {
		$.DispatchEvent( 'DOTAShowTextTooltip', panel, $.Localize(perkName+"_tooltip"));
	} )
	panel.SetPanelEvent( "onmouseout", function() {
		$.DispatchEvent( 'DOTAHideTextTooltip', panel);
	} )
}

function UpdateBlockPatreonsPerk(panel, currectPatreonLevel){
	panel.SetPanelEvent( "onmouseover", function() {
		$.DispatchEvent( 'DOTAShowTextTooltip', panel, $.Localize("#patreon_perks_list_error_tier_"+currectPatreonLevel));
	} )
	panel.SetPanelEvent( "onmouseout", function() {
		$.DispatchEvent( 'DOTAHideTextTooltip', panel);
	} )
}

function CreatePatreonsGamePerks(){
	if (patreonLevel > 0){
		$("#PatreonGamePerkButtonOption").visible = true;
		$("#PatreonGamePerkButtonPanel").visible = true;

		for (var x = 0; x < patreons_levels; x++) {
			var tier = x+1
			var patreonGamePerksTier = $.CreatePanel("Panel", $("#PatreonsGamePerksTierList"), "");
			patreonGamePerksTier.AddClass("PatreonGamePerksTier");

			var patreonGamePerksTierHeader = $.CreatePanel("Panel", patreonGamePerksTier, "");
			patreonGamePerksTierHeader.AddClass("PatreonGamePerksTierHeader");

			var patreonGamePerksTierHeaderText = $.CreatePanel("Label", patreonGamePerksTierHeader, "");
			patreonGamePerksTierHeaderText.AddClass("PatreonGamePerksTierHeaderTextMain");
			patreonGamePerksTierHeaderText.AddClass("PatreonGamePerksTierHeaderTextTier"+tier);
			patreonGamePerksTierHeaderText.text = $.Localize("#patreon_game_perk_tolltip_tier_"+tier);

			var perkPanelListForTier = $.CreatePanel("Panel", patreonGamePerksTier, "");
            perkPanelListForTier.AddClass("PerkPanelListForTier");

			for (var key in patreons_game_perks_have_only_low_tier) {
				if (patreons_game_perks[key] < patreonLevel){
					patreons_game_perks[key] = patreonLevel
				}
			}

			for (var key in patreons_game_perks) {
				if (patreons_game_perks[key] == tier){
					var perkPanel = $.CreatePanel("Panel", perkPanelListForTier, "");
					perkPanel.AddClass("GamePerkForPatreon");

					var perkIconImage = $.CreatePanel("Image", perkPanel, "");
					perkIconImage.AddClass("GamePerkImage");
					perkIconImage.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/icons/"+key+".png")
					perkIconImage.icon = key

					var perkLabelText = $.CreatePanel("Label", perkPanel, "");
					perkLabelText.AddClass("GamePerkText");
					perkLabelText.text = $.Localize(key);

					if (patreons_game_perks[key] == patreonLevel){
						perkIconImage.AddClass("GamePerkImageHover");
						SetPatreonsPerkButtonAction(perkIconImage, key);
					}else{
						perkIconImage.AddClass("GamePerkImageNotAvailable");
						perkLabelText.AddClass("GamePerkTextNotAvailable");
						UpdateBlockPatreonsPerk(perkIconImage, patreons_game_perks[key]);
					}
				}
			}
		}
	}
}

(function () {
	GameEvents.Subscribe('return_patreon_level', SetPlayerPatreonLevel);
	GameEvents.SendCustomGameEventToServer("check_patreon_level", {});
	$.Schedule(1, function() {
		CreatePatreonsGamePerks();
	});
})();
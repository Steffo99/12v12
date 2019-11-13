var COSMETIC_ABILITIES = {
	"high_five": true,
	"seasonal_ti9_banner": true,
	"seasonal_summon_cny_balloon": true,
	"seasonal_summon_dragon": true,
	"seasonal_summon_cny_tree": true,
	"seasonal_firecrackers": true,
	"seasonal_ti9_shovel": true,
	"seasonal_ti9_instruments": true,
	"seasonal_ti9_monkey": true,
	"seasonal_summon_ti9_balloon": true,
	"seasonal_throw_snowball": true,
	"seasonal_festive_firework": true,
	"seasonal_decorate_tree": true,
	"seasonal_summon_snowman": true
}

var hud = $.GetContextPanel().GetParent().GetParent().GetParent()
var lower_hud = hud.FindChildTraverse( "HUDElements" ).FindChild( "lower_hud" )
var center_with_stats = lower_hud.FindChild( "center_with_stats" )
var center_block = center_with_stats.FindChild( "center_block" )
var buff_container = lower_hud.FindChild( "BuffContainer" )

lower_hud.style.height = "100%"
center_with_stats.style.height = "100%"
center_block.style.height = "100%"

buff_container.FindChild( "buffs" ).style.transform = "translateY( -50px )"
buff_container.FindChild( "debuffs" ).style.transform = "translateY( -50px )"

var cosmetics = center_block.FindChild( "CosmeticAbilities" )

if ( !cosmetics ) {
	cosmetics = $.CreatePanel( "Panel", center_block, "CosmeticAbilities" )
	center_block.MoveChildBefore( cosmetics, center_block.FindChild( "center_bg" ) )
} else {
	cosmetics.RemoveAndDeleteChildren()
}

cosmetics.BLoadLayout( "file://{resources}/layout/custom_game/common/cosmetic_abilities/cosmetic_abilities.xml", false, false )

center_block.FindChildrenWithClassTraverse( "TertiaryAbilityContainer" )[0].style.visibility = "collapse"

var abilities_panel = center_block.FindChild( "AbilitiesAndStatBranch" ).FindChildTraverse( "abilities" )

setInterval(function HideAbilities() {
	for (var ability_panel of abilities_panel.Children()) {
		var ability_name = ability_panel.FindChildTraverse( "AbilityImage" ).abilityname

		if ( COSMETIC_ABILITIES[ability_name] ) {
			ability_panel.style.visibility = "collapse"
		} else {
			ability_panel.style.visibility = "visible"
		}
	}
}, 0);

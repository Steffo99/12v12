"use strict";

var skip = false

// Recieves a list of entities to replace the current selection
function Selection_New(msg)
{
    var entities = msg.entities
    //$.Msg("Selection_New ", entities)
    for (var i in entities) {
        if (i==1)
            GameUI.SelectUnit(entities[i], false) //New
        else
            GameUI.SelectUnit(entities[i], true) //Add
    };
    $.Schedule(0.03, SendSelectedEntities);
}

// Recieves a list of entities to add to the current selection
function Selection_Add(msg)
{
    var entities = msg.entities
    for (var i in entities) {
        //$.Msg("Selection_Add ", entities[i], " to ",GetSelectedEntities())
        GameUI.SelectUnit(entities[i], true)
    };
    $.Schedule(0.03, SendSelectedEntities);
}

// Removes a list of entities from the current selection
function Selection_Remove(msg)
{
    var remove_entities = msg.entities
    //$.Msg("Selection_Remove ", remove_entities)
    var selected_entities = GetSelectedEntities();
    for (var i in remove_entities) {
        var index = selected_entities.indexOf(remove_entities[i])
        if (index > -1)
            selected_entities.splice(index, 1)
    };

    if (selected_entities.length == 0)
    {
        Selection_Reset()
        return
    }

    for (var i in selected_entities) {
        if (i==0)
            GameUI.SelectUnit(selected_entities[i], false) //New
        else
            GameUI.SelectUnit(selected_entities[i], true) //Add
    };
    //$.Schedule(0.03, SendSelectedEntities);
}

// Fall back to the default selection
function Selection_Reset(msg)
{
    var playerID = Players.GetLocalPlayer()
    var heroIndex = Players.GetPlayerHeroEntityIndex(playerID)
    GameUI.SelectUnit(heroIndex, false)
    //$.Schedule(0.03, SendSelectedEntities);
}

// Filter & Sending
function OnUpdateSelectedUnit()
{
    //$.Msg( "OnUpdateSelectedUnit ", Entities.GetUnitName(Players.GetLocalPlayerPortraitUnit()), " ", Players.GetLocalPlayerPortraitUnit() );
    if (skip == true){
        skip = false;
        return
    }

    // Skips units from the selected group
    SelectionFilter(GetSelectedEntities())

    //$.Schedule(0.03, SendSelectedEntities);
}

// Updates the list of selected entities on server for this player
function SendSelectedEntities() {
    GameEvents.SendCustomGameEventToServer("selection_update", {entities: GetSelectedEntities()})
}

// Local player shortcut
function GetSelectedEntities(msg) {
    return Players.GetSelectedEntities(Players.GetLocalPlayer());
}

function Selection_Refresh(msg) {
    SendSelectedEntities();
}

// Returns an index of an override defined on lua with npcHandle:SetSelectionOverride(reselect_unit)
function GetSelectionOverride(entityIndex) {
    var table = CustomNetTables.GetTableValue("selection", entityIndex)
    return table ? table.entity : -1
}

(function () {
    // Custom event listeners
    GameEvents.Subscribe( "selection_new", Selection_New);
    GameEvents.Subscribe( "selection_add", Selection_Add);
    GameEvents.Subscribe( "selection_remove", Selection_Remove);
    GameEvents.Subscribe( "selection_reset", Selection_Reset);
    GameEvents.Subscribe( "selection_refresh", Selection_Refresh);
})();
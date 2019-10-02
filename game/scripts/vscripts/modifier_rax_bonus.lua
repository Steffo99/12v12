modifier_rax_bonus = class({})

function modifier_rax_bonus:IsHidden() return true end
function modifier_rax_bonus:IsPurgable() return false end
function modifier_rax_bonus:IsPurgeException() return false end
function modifier_rax_bonus:RemoveOnDeath() return false end

function modifier_rax_bonus:DeclareFunctions()
	return { MODIFIER_PROPERTY_RESPAWNTIME }
end

function modifier_rax_bonus:GetModifierConstantRespawnTime()
	if self:GetParent():GetTeam() == DOTA_TEAM_GOODGUYS then
		print(_G.goodraxbonus)
		return -_G.goodraxbonus
	else
		print(_G.badraxbonus)
		return -_G.badraxbonus
	end
	--return -100
end
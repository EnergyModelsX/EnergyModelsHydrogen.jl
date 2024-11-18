"""
    EMB.check_node_data(n::HydrogenStorage, data::InvestmentData, 𝒯, modeltype::AbstractInvestmentModel, check_timeprofiles::Bool)

As [`HydrogenStorage`](@ref) nodes cannot utilize investments at the time being, a separate
function is required

## Checks
- No investment data is allowed
"""
function EMB.check_node_data(
    n::HydrogenStorage,
    data::InvestmentData,
    𝒯,
    modeltype::AbstractInvestmentModel,
    check_timeprofiles::Bool,
)

    @assert_or_log(
        !has_investment(n),
        "`InvestmentData` is not allowed for `HydrogenStorage` nodes."
    )
end

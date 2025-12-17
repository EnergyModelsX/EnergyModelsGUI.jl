using JuMP
using SCIP
using TimeStruct

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsHydrogen
using EnergyModelsCO2
using EnergyModelsRenewableProducers
using EnergyModelsHeat
using EnergyModelsInvestments

const EMB    = EnergyModelsBase
const EMG    = EnergyModelsGeography
const EMH2   = EnergyModelsHydrogen
const EMCO2  = EnergyModelsCO2
const EMR    = EnergyModelsRenewableProducers
const EMHeat = EnergyModelsHeat
const EMI    = EnergyModelsInvestments
const TS     = TimeStruct

"""
All-in-one-case: combines all nodes from the main EMX packages.

This comprehensive example includes:
- Two areas (EnergyModelsGeography) transferring `Power` and `CO2` with investment 
  transmission corridors: power line (ContinuousInvestment) + CO2 pipeline (SemiContinuousInvestment)
- One dedicated water-power cascaded hydro subsystem (detailed hydropower), connected to the hub via `Power`.
- CO2 retrofit chain + standalone CO2 source/storage chain, both connected to hub via `CO2` and `Power`.
- Hydrogen chain (electrolyzer + H2 storage), connected to hub via `Power` and `H2`.
- Battery reserve chain + simple nondispatchable RES chain + simple hydro balancing chain, all connected to hub via `Power`.
- District heating chain connected to hub via `Power` + `Heat`.
- Reformer block connected via hub for `NG`/`Power`/`H2`/`CO2`.
- Sink-source examples: both operational and investment variants, connected via hub for `Power`.

All subsystems are connected through the global multi-carrier hub, demonstrating integration of:
- EnergyModelsBase v0.9.4
- EnergyModelsCO2 v0.7.6
- EnergyModelsGeography v0.11.4
- EnergyModelsHeat v0.1.4
- EnergyModelsHydrogen v0.8.3
- EnergyModelsInvestments v0.8.1
- EnergyModelsRenewableProducers v0.6.7
"""
function generate_all_in_one_case()
    # -----------------------------
    # 1) Resources (unified naming)
    # -----------------------------
    CO2 = ResourceEmit("CO2", 1.0)
    CO2_proxy = ResourceCarrier("CO2 proxy", 0.0)
    Power = ResourceCarrier("Power", 0.0)
    H2 = ResourceCarrier("H2", 0.0)
    NG = ResourceCarrier("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Water = ResourceCarrier("Water", 0.0)
    reserve_down = ResourceCarrier("reserve down", 0.0)

    HeatLT = ResourceHeat("HeatLT", 30.0, 30.0)
    HeatHT = ResourceHeat("HeatHT", 80.0, 30.0)

    products = [Power, H2, CO2, CO2_proxy, NG, Coal, HeatLT, HeatHT, Water, reserve_down]

    # -----------------------------
    # 2) Time structure (keep smaller for SCIP)
    # -----------------------------
    op_duration = 3         # hours
    op_number = 8         # 8 periods (keeps MILP manageable)
    operational_periods = SimpleTimes(op_number, op_duration)
    op_per_strat = 8760
    T = TwoLevel(2, 1, operational_periods; op_per_strat)  # 2 strategic periods

    prof_n(x) = OperationalProfile(fill(x, op_number))
    # helper: repeat a vector to length op_number
    function repeat_to_len(v::Vector{<:Number}, n::Int)
        out = Float64[]
        while length(out) < n
            append!(out, Float64.(v))
        end
        return OperationalProfile(out[1:n])
    end

    # -----------------------------
    # 3) Investment model (so we can include investment nodes + corridors)
    # -----------------------------
    model = InvestmentModel(
        Dict(
            CO2 => FixedProfile(1e12),
        ),
        Dict(
            CO2 => FixedProfile(0.0),
        ),
        CO2,
        0.07,
    )

    # -----------------------------
    # 4) Global hub
    # -----------------------------
    hub = GenAvailability(
        "hub",
        [Power, H2, CO2, CO2_proxy, NG, Coal, HeatLT, HeatHT, reserve_down],
    )

    nodes = EMB.Node[hub]
    links = EMB.Link[]

    # ============================================================
    # A) Hydrogen: electrolyzer + H2 storage + H2 demand + power source
    # ============================================================
    el_source = RefSource(
        "hub-electricity_source",
        FixedProfile(200),
        prof_n(30.0),
        FixedProfile(0.0),
        Dict(Power => 1.0),
    )
    pem = Electrolyzer(
        "PEM",
        FixedProfile(100),
        FixedProfile(5),
        FixedProfile(0),
        Dict(Power => 1),
        Dict(H2 => 0.69),
        ExtensionData[],
        LoadLimits(0, 1),
        0.1,
        FixedProfile(1.5e5),
        65000,
    )
    h2_store = HydrogenStorage{CyclicStrategic}(
        "hydrogen storage",
        StorCap(FixedProfile(30)),
        StorCap(FixedProfile(600)),
        H2, Power,
        2.0, 20.0,
        30.0, 45.0, 150.0,
    )
    h2_demand = RefSink(
        "hub-h2_demand",
        repeat_to_len([0, 10, 50, 30], op_number),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(200)),
        Dict(H2 => 1.0),
    )

    append!(nodes, [el_source, pem, h2_store, h2_demand])

    # source -> hub (sources cannot take inputs)
    push!(links, Direct("el_source-to-hub", el_source, hub, Linear()))
    push!(links, Direct("hub-to-pem", hub, pem, Linear()))
    push!(links, Direct("pem-to-hub", pem, hub, Linear()))
    push!(links, Direct("hub-to-h2_store", hub, h2_store, Linear()))
    push!(links, Direct("h2_store-to-hub", h2_store, hub, Linear()))
    push!(links, Direct("hub-to-h2_demand", hub, h2_demand, Linear()))

    # ============================================================
    # B) Battery reserve system
    # ============================================================
    batt = ReserveBattery{CyclicStrategic}(
        "battery",
        StorCap(FixedProfile(30)),
        StorCap(FixedProfile(80)),
        StorCap(FixedProfile(30)),
        Power,
        Dict(Power => 0.9),
        Dict(Power => 0.9),
        CycleLife(900, 0.2, FixedProfile(2e5)),
        ResourceCarrier[],
        [reserve_down],
    )
    reserve_down_sink = RefSink(
        "reserve down demand",
        FixedProfile(10),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e2)),
        Dict(reserve_down => 1),
    )
    append!(nodes, [batt, reserve_down_sink])

    push!(links, Direct("hub-batt", hub, batt, Linear()))
    push!(links, Direct("batt-hub", batt, hub, Linear()))
    push!(links, Direct("batt-reserve_down", batt, reserve_down_sink, Linear()))

    # ============================================================
    # C) Simple NonDisRES + balancing source
    # ============================================================
    bal_source = RefSource(
        "balancing_source",
        FixedProfile(50),
        prof_n(60.0),
        FixedProfile(0.0),
        Dict(Power => 1),
    )
    wind_simple = NonDisRES(
        "wind_simple",
        FixedProfile(80),
        repeat_to_len([0.9, 0.4, 0.1, 0.8], op_number),
        FixedProfile(10),
        FixedProfile(0),
        Dict(Power => 1),
    )
    append!(nodes, [bal_source, wind_simple])

    push!(links, Direct("bal_source-to-hub", bal_source, hub, Linear()))
    push!(links, Direct("wind_simple-to-hub", wind_simple, hub, Linear()))

    # ============================================================
    # D) Simple HydroStor balancing
    # ============================================================
    hydro_simple = HydroStor{CyclicStrategic}(
        "hydropower_simple",
        StorCapOpexFixed(FixedProfile(200), FixedProfile(0.0)),
        StorCapOpexVar(FixedProfile(30), FixedProfile(0.0)),
        FixedProfile(50),
        FixedProfile(5),
        FixedProfile(0.0),
        Power,
        Dict(Power => 0.9),
        Dict(Power => 1.0),
        Data[],
    )
    append!(nodes, [hydro_simple])

    push!(links, Direct("hub-hydro_simple", hub, hydro_simple, Linear()))
    push!(links, Direct("hydro_simple-hub", hydro_simple, hub, Linear()))

    # ============================================================
    # E) District heating
    # ============================================================
    dh_source = RefSource(
        "district_heat_source",
        FixedProfile(60),
        FixedProfile(10),
        FixedProfile(0),
        Dict(HeatLT => 1),
    )
    heat_pump = HeatPump(
        "heat_pump",
        FixedProfile(40),
        0,
        EMHeat.t_supply(HeatLT),
        EMHeat.t_supply(HeatHT),
        FixedProfile(0.5),
        HeatLT,
        Power,
        FixedProfile(0),
        FixedProfile(0),
        Dict(HeatHT => 1),
    )
    tes = BoundRateTES{CyclicRepresentative}(
        "TES",
        StorCap(FixedProfile(400)),
        HeatHT,
        0.02,
        0.05,
        0.15,
        Dict(HeatHT => 1),
        Dict(HeatHT => 1),
    )
    heat_demand = RefSink(
        "heat_demand",
        repeat_to_len([0, 30, 10, 50], op_number),
        Dict(:surplus => FixedProfile(100), :deficit => FixedProfile(1000)),
        Dict(HeatHT => 1),
    )
    append!(nodes, [dh_source, heat_pump, tes, heat_demand])

    push!(links, Direct("dh_source-to-heat_pump", dh_source, heat_pump, Linear()))
    push!(links, Direct("hub-to-heat_pump_power", hub, heat_pump, Linear()))
    push!(links, Direct("heat_pump-to-hub_heatHT", heat_pump, hub, Linear()))
    push!(links, Direct("hub-to-heat_demand", hub, heat_demand, Linear()))
    push!(links, Direct("heat_pump-to-TES", heat_pump, tes, Linear()))
    push!(links, Direct("TES-to-hub", tes, hub, Linear()))

    push!(
        links,
        DHPipe(
            "dh_pipe_source_to_hp",
            dh_source,
            heat_pump,
            FixedProfile(60),
            2_000_000.0,
            0.025e-6,
            FixedProfile(10.0),
            HeatLT,
        ),
    )

    # ============================================================
    # F) CO2 retrofit chain
    # ============================================================
    ng_source_ccgt = RefSource(
        "NG_source_for_CCGT",
        FixedProfile(2000),
        FixedProfile(5.5),
        FixedProfile(0),
        Dict(NG => 1),
    )
    ccgt = RefNetworkNodeRetrofit(
        "CCGT_retrofittable",
        FixedProfile(800),
        FixedProfile(5.5),
        FixedProfile(0),
        Dict(NG => 1.66),
        Dict(Power => 1),
        CO2_proxy,
        Data[CaptureEnergyEmissions(1.0)],
    )
    ccs = CCSRetroFit(
        "CCS_unit",
        FixedProfile(400),
        FixedProfile(0),
        FixedProfile(0),
        Dict(NG => 1.0, CO2_proxy => 0),
        Dict(CO2 => 0),
        CO2_proxy,
        Data[CaptureEnergyEmissions(0.9)],
    )
    co2_store_big = CO2Storage(
        "CO2_storage_big",
        StorCapOpex(FixedProfile(400), FixedProfile(9.1), FixedProfile(0)),
        StorCap(FixedProfile(1e8)),
        CO2,
        Dict(CO2 => 1),
    )
    el_demand_big = RefSink(
        "electricity_demand_big",
        FixedProfile(200),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e4)),
        Dict(Power => 1),
    )
    append!(nodes, [ng_source_ccgt, ccgt, ccs, co2_store_big, el_demand_big])

    # correct direction: source -> user
    push!(links, Direct("ng_source_ccgt-to-ccgt", ng_source_ccgt, ccgt, Linear()))
    push!(links, Direct("ccgt-to-hub_power", ccgt, hub, Linear()))
    push!(links, Direct("ccgt-to-ccs", ccgt, ccs, Linear()))
    push!(links, Direct("hub-to-ccs_fuel", hub, ccs, Linear()))
    push!(links, Direct("ccs-to-co2_store_big", ccs, co2_store_big, Linear()))
    push!(links, Direct("hub-to-el_demand_big", hub, el_demand_big, Linear()))

    # ============================================================
    # G) Standalone CO2 source + CO2 storage (connected via hub)
    # ============================================================
    co2_src = CO2Source(
        "CO2_source_negative",
        FixedProfile(50),
        StrategicProfile([-30, -20]),
        FixedProfile(1),
        Dict(CO2 => 1),
    )
    co2_store_small = CO2Storage(
        "CO2_storage_small",
        StorCapOpex(FixedProfile(50), FixedProfile(9.1), FixedProfile(1)),
        StorCap(FixedProfile(1e6)),
        CO2,
        Dict(CO2 => 1),
    )
    append!(nodes, [co2_src, co2_store_small])

    # connect the CO2 source to the hub (direction matters)
    push!(links, Direct("co2_src-to-hub", co2_src, hub, Linear()))
    # send CO2 from hub into the storage (do NOT assume storage can dispatch back out)
    push!(links, Direct("hub-to-co2_store_small", hub, co2_store_small, Linear()))

    # ============================================================
    # H) Geographic 2-area network (existing) + investment corridor modes
    # ============================================================
    𝒫_geo = [NG, Coal, Power, CO2]

    reg1_av = GeoAvailability("Reg_1-Availability", 𝒫_geo)
    reg1_coal_src = RefSource(
        "Reg_1-Coal_source",
        FixedProfile(100),
        FixedProfile(9),
        FixedProfile(0),
        Dict(Coal => 1),
    )
    reg1_coal_pp = RefNetworkNode(
        "Reg_1-Coal_power_plant",
        FixedProfile(25),
        FixedProfile(6),
        FixedProfile(0),
        Dict(Coal => 2.5),
        Dict(Power => 1),
        [EmissionsEnergy()],
    )
    reg1_co2_stor = RefStorage{AccumulatingEmissions}(
        "Reg_1-CO2_storage_geo",
        StorCapOpex(FixedProfile(60), FixedProfile(9.1), FixedProfile(0)),
        StorCap(FixedProfile(600)),
        CO2,
        Dict(CO2 => 1, Power => 0.02),
        Dict(CO2 => 1),
    )
    reg1_dem = RefSink(
        "Reg_1-Electricity_demand",
        FixedProfile(10),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e3)),
        Dict(Power => 1),
    )
    area_1 = RefArea(1, "Coal area", 6.62, 51.04, reg1_av)

    reg2_av = GeoAvailability("Reg_2-Availability", 𝒫_geo)
    reg2_ng_src = RefSource(
        "Reg_2-NG_source",
        FixedProfile(100),
        FixedProfile(30),
        FixedProfile(0),
        Dict(NG => 1),
    )
    reg2_ng_ccs_pp = RefNetworkNode(
        "Reg_2-ng+CCS_power_plant",
        FixedProfile(25),
        FixedProfile(5.5),
        FixedProfile(0),
        Dict(NG => 2.0),
        Dict(Power => 1, CO2 => 0),
        [CaptureEnergyEmissions(0.9)],
    )
    reg2_dem = RefSink(
        "Reg_2-Electricity_demand",
        repeat_to_len([10, 20, 30, 20], op_number),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(5e2)),
        Dict(Power => 1),
    )
    area_2 = RefArea(2, "Natural gas area", 6.83, 53.45, reg2_av)

    append!(
        nodes,
        [reg1_av, reg1_coal_src, reg1_coal_pp, reg1_co2_stor, reg1_dem,
            reg2_av, reg2_ng_src, reg2_ng_ccs_pp, reg2_dem],
    )

    append!(
        links,
        [
            Direct("Reg_1-av-coal_pp", reg1_av, reg1_coal_pp, Linear()),
            Direct("Reg_1-av-CO2_stor", reg1_av, reg1_co2_stor, Linear()),
            Direct("Reg_1-av-demand", reg1_av, reg1_dem, Linear()),
            Direct("Reg_1-coal_src-av", reg1_coal_src, reg1_av, Linear()),
            Direct("Reg_1-coal_pp-av", reg1_coal_pp, reg1_av, Linear()),
            Direct("Reg_2-av-NG_pp", reg2_av, reg2_ng_ccs_pp, Linear()),
            Direct("Reg_2-av-demand", reg2_av, reg2_dem, Linear()),
            Direct("Reg_2-NG_src-av", reg2_ng_src, reg2_av, Linear()),
            Direct("Reg_2-NG_pp-av", reg2_ng_ccs_pp, reg2_av, Linear()),
        ],
    )

    # --- Investment transmission modes (from investments.jl) ---
    power_inv_data = SingleInvData(
        FixedProfile(150 * 1e3),
        FixedProfile(60),
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
    )
    power_line = RefStatic(
        "power_line",
        Power,
        FixedProfile(0),          # initial = 0, invest to build
        FixedProfile(0.02),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [power_inv_data],
    )

    co2_pipe_inv_data = SingleInvData(
        FixedProfile(260 * 1e3),
        FixedProfile(40),
        SemiContinuousInvestment(FixedProfile(5), FixedProfile(20)),
    )
    co2_pipe = PipeSimple(
        "co2_pipeline",
        CO2,
        CO2,
        Power,
        FixedProfile(0.01),
        FixedProfile(0),          # initial = 0, invest to build
        FixedProfile(0),
        FixedProfile(0),
        FixedProfile(0),
        [co2_pipe_inv_data],
    )

    transmissions = [Transmission(area_2, area_1, [power_line, co2_pipe])]
    areas = [area_1, area_2]

    # Connect geo subsystem to global hub
    push!(links, Direct("hub-to-Reg_2_av", hub, reg2_av, Linear()))
    push!(links, Direct("Reg_2_av-to-hub", reg2_av, hub, Linear()))

    # ============================================================
    # I) Detailed cascaded hydropower (power-only coupling to hub)
    # ============================================================
    m3s_to_mm3 = 3.6e-3

    water_source = RefSource(
        "water_source",
        FixedProfile(0),
        FixedProfile(0),
        FixedProfile(0),
        Dict(Water => 1.0),
    )

    reservoir_up = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_up",
        StorCap(FixedProfile(10)),
        FixedProfile(10*m3s_to_mm3),
        Water,
    )
    reservoir_down = HydroReservoir{CyclicStrategic}(
        "hydro_reservoir_down",
        StorCap(FixedProfile(10)),
        FixedProfile(0),
        Water,
    )

    hydro_gen_cap = 20.0
    gen_up = HydroGenerator(
        "hydro_generator_up",
        FixedProfile(hydro_gen_cap),
        PqPoints([0, 10, 20] / hydro_gen_cap, [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap),
        FixedProfile(0), FixedProfile(0),
        Power, Water,
    )
    gen_down = HydroGenerator(
        "hydro_generator_down",
        FixedProfile(hydro_gen_cap),
        PqPoints([0, 10, 20] / hydro_gen_cap, [0, 10, 22] * m3s_to_mm3 / hydro_gen_cap),
        FixedProfile(0), FixedProfile(0),
        Power, Water,
    )

    pump_cap = 30.0
    pump = HydroPump(
        "hydro_pump",
        FixedProfile(pump_cap),
        PqPoints([0, 15, 30] / pump_cap, [0, 12, 20] * m3s_to_mm3 / pump_cap),
        FixedProfile(0), FixedProfile(0),
        Power, Water,
    )

    gate = HydroGate(
        "hydro_gate",
        FixedProfile(20*m3s_to_mm3),
        FixedProfile(0),
        FixedProfile(0),
        Water,
    )
    ocean = RefSink(
        "ocean",
        FixedProfile(0),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(0)),
        Dict(Water => 1.0),
    )

    hydro_av = GenAvailability("hydro_av", [Power])

    price4 = [10, 60, 15, 62]
    market_sale = RefSink(
        "market_sale",
        FixedProfile(0),
        Dict(:surplus => repeat_to_len(-price4, op_number),
            :deficit => repeat_to_len(price4, op_number)),
        Dict(Power => 1.0),
    )
    market_buy = RefSource(
        "market_buy",
        FixedProfile(1000),
        repeat_to_len(price4 .+ 0.01, op_number),
        FixedProfile(0),
        Dict(Power => 1.0),
    )

    append!(
        nodes,
        [
            water_source,
            reservoir_up,
            reservoir_down,
            gen_up,
            gen_down,
            pump,
            gate,
            ocean,
            hydro_av,
            market_sale,
            market_buy,
        ],
    )

    append!(
        links,
        [
            Direct("water_source-res_up", water_source, reservoir_up, Linear()),
            Direct("res_up-gen_up", reservoir_up, gen_up, Linear()),
            Direct("res_up-gate", reservoir_up, gate, Linear()),
            Direct("gen_up-res_down", gen_up, reservoir_down, Linear()),
            Direct("gate-res_down", gate, reservoir_down, Linear()),
            Direct("res_down-pump", reservoir_down, pump, Linear()),
            Direct("pump-res_up", pump, reservoir_up, Linear()),
            Direct("res_down-gen_down", reservoir_down, gen_down, Linear()),
            Direct("gen_down-ocean", gen_down, ocean, Linear()),
            Direct("gen_up-hydro_av", gen_up, hydro_av, Linear()),
            Direct("gen_down-hydro_av", gen_down, hydro_av, Linear()),
            Direct("hydro_av-pump", hydro_av, pump, Linear()),
            Direct("hydro_av-market_sale", hydro_av, market_sale, Linear()),
            Direct("market_buy-hydro_av", market_buy, hydro_av, Linear()),
        ],
    )

    push!(links, Direct("hydro_av-to-hub", hydro_av, hub, Linear()))
    push!(links, Direct("hub-to-hydro_av", hub, hydro_av, Linear()))

    # ============================================================
    # J) Reformer block (MILP, needs SCIP) – connected via hub
    # ============================================================
    reformer = Reformer(
        "reformer",
        FixedProfile(30),
        FixedProfile(5),
        FixedProfile(0),
        Dict(NG => 1.25, Power => 0.11),
        Dict(H2 => 1.0, CO2 => 0),
        ExtensionData[CaptureEnergyEmissions(0.92)],
        LoadLimits(0.2, 1.0),
        CommitParameters(FixedProfile(0.2), FixedProfile(3)),
        CommitParameters(FixedProfile(0.2), FixedProfile(3)),
        CommitParameters(FixedProfile(0.02), FixedProfile(4)),
        RampBi(FixedProfile(0.1)),
    )
    h2_demand_ref = RefSink(
        "h2_demand_reformer",
        repeat_to_len([0, 5, 10, 5], op_number),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(150)),
        Dict(H2 => 1),
    )
    co2_sink_ref = RefSink(
        "CO2_storage_reformer_sink",
        FixedProfile(0),
        Dict(:surplus => FixedProfile(9.1), :deficit => FixedProfile(20)),
        Dict(CO2 => 1),
    )
    append!(nodes, [reformer, h2_demand_ref, co2_sink_ref])

    push!(links, Direct("hub-to-reformer", hub, reformer, Linear()))
    push!(links, Direct("reformer-to-hub", reformer, hub, Linear()))
    push!(links, Direct("hub-to-h2_demand_reformer", hub, h2_demand_ref, Linear()))
    push!(links, Direct("reformer-to-co2_sink_ref", reformer, co2_sink_ref, Linear()))

    # ============================================================
    # K) Sink-source examples merged in through the hub
    #    - operational sink_source.jl
    #    - investment sink_source_invest.jl
    # ============================================================

    # (K1) plain sink-source
    ss_source = RefSource(
        "ss_electricity_source",
        FixedProfile(50),
        FixedProfile(30),
        FixedProfile(0),
        Dict(Power => 1),
    )
    ss_demand = RefSink(
        "ss_electricity_demand",
        repeat_to_len([20, 30, 40, 30], op_number),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(Power => 1),
    )
    append!(nodes, [ss_source, ss_demand])
    push!(links, Direct("ss_source-to-hub", ss_source, hub, Linear()))
    push!(links, Direct("hub-to-ss_demand", hub, ss_demand, Linear()))

    # (K2) investment sink-source: source starts at 0 and can be built
    lifetime = FixedProfile(15)
    inv_data_source = SingleInvData(
        FixedProfile(300 * 1e3),
        FixedProfile(50),
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        RollingLife(lifetime),
    )
    ss_inv_source = RefSource(
        "ss_inv_electricity_source",
        FixedProfile(0),
        FixedProfile(10),
        FixedProfile(5),
        Dict(Power => 1),
        [inv_data_source],
    )
    ss_inv_demand = RefSink(
        "ss_inv_electricity_demand",
        repeat_to_len([20, 30, 40, 30], op_number),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(Power => 1),
    )
    append!(nodes, [ss_inv_source, ss_inv_demand])
    push!(links, Direct("ss_inv_source-to-hub", ss_inv_source, hub, Linear()))
    push!(links, Direct("hub-to-ss_inv_demand", hub, ss_inv_demand, Linear()))

    # -----------------------------
    # FINAL Case assembly
    # -----------------------------
    case = Case(
        T,
        products,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )

    return case, model
end

function run_all_in_one_case()
    case, model = generate_all_in_one_case()

    optimizer = optimizer_with_attributes(
        SCIP.Optimizer,
        MOI.Silent() => true,
        "display/verblevel" => 0,
        "limits/time" => 180.0,
        "limits/gap" => 0.02,
    )

    m = run_model(case, model, optimizer)

    # The case can be visualized with
    gui = GUI(
        case;
        model = m,
        design_path = joinpath(@__DIR__, "design/example_all_structures"),
    )

    return case, model, m, gui
end

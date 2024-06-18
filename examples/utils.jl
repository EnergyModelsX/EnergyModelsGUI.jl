function get_cable_data(; type::String="TXSP 1x3x150 AL")
    # For the El line type TXSP 1x3x150 AL we have the following
    if type == "TXSP 1x3x150 AL"
        max_current = 310 # A
        #reactance = 0.12 # ohm/km
        #resitance = 0.206 # ohm/km
        voltage = 22 # kV
        #cableLength = 0.0 # km
        trans_cap = voltage * max_current # P = V ⋅ I
        loss = 0.0
        #loss = FixedProfile(6.5e-5/0.6) # if calbeLength = 0.1
        return trans_cap, loss
    end
end

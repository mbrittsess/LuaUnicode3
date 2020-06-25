local ChunkInitNames = {
    "us4l.internals.MasterTable.Init_Plane0_1",
    "us4l.internals.MasterTable.Init_Plane0_2",
    "us4l.internals.MasterTable.Init_Plane0_3",
    "us4l.internals.MasterTable.Init_Plane0_4",
    "us4l.internals.MasterTable.Init_Plane0_5",
    "us4l.internals.MasterTable.Init_Plane0_6",
    "us4l.internals.MasterTable.Init_Plane0_7",
    "us4l.internals.MasterTable.Init_Plane0_8",
    "us4l.internals.MasterTable.Init_Plane0_9",
    "us4l.internals.MasterTable.Init_Plane1_1",
    "us4l.internals.MasterTable.Init_Plane1_2",
    "us4l.internals.MasterTable.Init_Plane2_1",
    "us4l.internals.MasterTable.Init_Plane2_2",
    "us4l.internals.MasterTable.Init_Plane2_3",
    "us4l.internals.MasterTable.Init_Plane2_4",
    "us4l.internals.MasterTable.Init_Plane2_5",
    "us4l.internals.MasterTable.Init_Plane2_6",
    "us4l.internals.MasterTable.Init_Plane14_1"
}

for _,ChunkInitName in ipairs( ChunkInitNames ) do
    require( ChunkInitName )
end

require( "us4l.internals.MasterTable.InitFunctions" ).ProcessDeferredUStrings()

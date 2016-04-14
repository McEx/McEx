use Mix.Config

config :mc_ex,
  view_distance: 8,
  auth: [online: true]

config :mc_chunk,
  block_store: McEx.Native.BlockStore

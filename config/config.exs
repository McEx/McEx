use Mix.Config

config :mc_ex,
  auth: [online: true]

config :mc_chunk,
  block_store: McEx.Native.BlockStore

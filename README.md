McEx

McEx is a Minecraft server written in Elixir and Rust. All the networking and logic is implemented in Elixir, while the low level chunk data handling is done in Rust.

It is written with distribution in mind. It will take advantage of all cores on the machine by default. In the future it should be possible to offload the computationally heavy parts (like chunk generation, chunk servers, even anticheat) to other machines, while keeping the core parts that require more swift communication on a single machine.

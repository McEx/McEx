defmodule McEx.Net.Crypto.KeyServer do
  require Record
  Record.defrecord :rsa_priv_key, :RSAPrivateKey, Record.extract(:RSAPrivateKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  Record.defrecord :rsa_pub_key, :RSAPublicKey, Record.extract(:RSAPublicKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get_keys do
    GenServer.call(__MODULE__, :get_keys)
  end

  def init(:ok) do
    {:ok, private_key} = :cutkey.rsa(1024, 65537, return: :key)
    private_key_data = rsa_priv_key(private_key)
    public_key = rsa_pub_key(modulus: private_key_data[:modulus], publicExponent: private_key_data[:publicExponent])
    {:SubjectPublicKeyInfo, public_key_asn, :not_encrypted} = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    {:ok, {public_key_asn, private_key}}
  end

  def handle_call(:get_keys, _from, state) do
    {:reply, state, state}
  end
end

defmodule McEx.Net.Crypto do
  def gen_token do
    :crypto.strong_rand_bytes(16)
  end

  def get_auth_init_data do
    {McEx.Net.Crypto.KeyServer.get_keys, gen_token}
  end

  defmodule CryptData do
    defstruct key: nil, ivec: nil
  end

  def encrypt(plaintext, %CryptData{} = cryptdata) do 
    encrypt(plaintext, cryptdata, <<>>)
  end
  defp encrypt(<<plain_byte::binary-size(1), plain_rest::binary>>, %CryptData{key: key, ivec: ivec} = cryptdata, ciph_base) do
    ciphertext = :crypto.block_encrypt(:aes_cfb8, key, ivec, plain_byte)
    ivec = update_ivec(ivec, ciphertext)
    encrypt(plain_rest, %{cryptdata | ivec: ivec}, ciph_base <> ciphertext)
  end
  defp encrypt(<<>>, %CryptData{} = cryptdata, ciphertext) do
    {cryptdata, ciphertext}
  end

  def decrypt(ciphertext, %CryptData{} = cryptdata), do: decrypt(ciphertext, cryptdata, <<>>)
  defp decrypt(<<ciph_byte::binary-size(1), ciph_rest::binary>> = ciph, %CryptData{key: key, ivec: ivec} = cryptdata, plain_base) do
    plaintext = :crypto.block_decrypt(:aes_cfb8, key, ivec, ciph_byte)
    ivec = update_ivec(ivec, ciph_byte)
    decrypt(ciph_rest, %{cryptdata | ivec: ivec}, plain_base <> plaintext)
  end
  defp decrypt(<<>>, %CryptData{} = cryptdata, plaintext) do
    {cryptdata, plaintext}
  end

  defp update_ivec(ivec, data) when byte_size(data) == 1 and byte_size(ivec) == 16 do
    <<_::binary-size(1), ivec_end::binary-size(15)>> = ivec
    <<ivec_end::binary, data::binary>>
  end

  defp stupid_sha1(data) do
    <<hash::signed-integer-size(160)>> = :crypto.hash(:sha, data)

    sign = hash < 0
    if sign, do: hash = -hash

    hash_string = String.downcase(Integer.to_string(hash, 16))

    case sign do
      false -> hash_string
      true -> "-" <> hash_string
    end
  end

  def verification_hash(secret, pubkey) do
    stupid_sha1(secret <> pubkey)
  end

  defmodule LoginVerifyResponse do
    defstruct [:id, :name]
  end
  def verify_user_login(pubkey, secret, name) do
    hash = verification_hash(secret, pubkey)
    query = URI.encode_query(%{username: name, serverId: hash})
    response = %{status_code: 200, body: json} = 
        HTTPotion.get("https://sessionserver.mojang.com/session/minecraft/hasJoined?" <> query)
    %{name: ^name} = Poison.decode!(json, as: LoginVerifyResponse)
  end
end

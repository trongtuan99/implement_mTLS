Implement mTLS for internal microservices

1. Generate required files: Generate the Root CA certificate:

```
  Note:
  -days 365: expiration period
  1y: 365
  2y: 730
  5y: 1825
  10y: 3650
```

- create `ca.cnf`: Creating the Certificate Authority's Certificate and Keys

```
  [ req ]
  default_bits = 4096
  distinguished_name = req_distinguished_name
  x509_extensions = v3_ca
  string_mask = utf8only
  prompt = no

  [ req_distinguished_name ]
  C = VN
  ST = HCM
  L = HoChiMinh
  O = DEV
  OU = SERVER
  CN = CNCA
  emailAddress = ca@example.com

  [ v3_ca ]
  subjectKeyIdentifier = hash
  authorityKeyIdentifier = keyid:always,issuer
  basicConstraints = critical, CA:true, pathlen:1
  keyUsage = critical, digitalSignature, cRLSign, keyCertSign
```

- NEXT STEP

```ruby
  # Use this command to create a password-protected, 4096-bit private key

  openssl genrsa -aes256 -passout pass:password -out ca.pass.key 4096

  # encrypt private key

  openssl rsa -passin pass:password -in ca.pass.key -out ca.key

  # generate crt file

  openssl req -config ca.cnf -key private/ca.key -new -x509 -days 3650 -sha256 -extensions v3_ca -out certs/ca.crt

  # ca.pass.key could be deleted at this step
```

- create `server.cnf`: Creating the Server's Certificate and Keys (IMPORTANT! CommonName: must provide hostname or IP address)

```
  [ req ]
  default_bits = 4096
  prompt = no
  default_md = sha256
  distinguished_name = req_distinguished_name
  req_extensions = req_ext

  [ req_distinguished_name ]
  C = VN
  ST = HCM
  L = HoChiMinh
  O = DEV
  OU = SERVER
  CN = localhost

  [ req_ext ]
  subjectAltName = @alt_names

  [ alt_names ]
  DNS.1 = localhost
```

- NEXT STEP

```ruby
  openssl genrsa -aes256 -passout pass:password -out server.pass.key 4096

  openssl rsa -passin pass:password -in server.pass.key -out server.key

  openssl req -config ../cnf/server.cnf -new -key server.key -out server.csr

  openssl x509 -req -days 365 -in server.csr -extfile ../cnf/server.cnf -extensions req_ext -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
```

- create `client.cnf`: Creating the Client's Certificate and Keys

```
  [ req ]
  default_bits = 4096
  prompt = no
  default_md = sha256
  distinguished_name = req_distinguished_name
  req_extensions = req_ext

  [ req_distinguished_name ]
  C = VN
  ST = HCM
  L = HoChiMinh
  O = DEV
  OU = CLIENT
  CN = client

  [ req_ext ]
  subjectAltName = @alt_names

  [ alt_names ]
  DNS.1 = client
```

- NEXT STEP

```ruby
  openssl genrsa -aes256 -passout pass:password -out client.pass.key 4096

  openssl rsa -passin pass:password -in client.pass.key -out client.key

  openssl req -config ../cnf/client.cnf -new -key client.key -out client.csr

  openssl x509 -req -days 365 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out client.crt

```

2. Server config:

```
on config/environments/production.rb:

  config.force_ssl = true

then create folder root/certs and copy 3 required files (server.key, server.crt and ca.crt)

start on cmd:

  rails s -b 'ssl://localhost:3001?cert=certs/server.crt&key=certs/server.key&verify_mode=force_peer&ca=certs/ca.crt'
```

3. Client config:

```
create folder root/certs and copy 3 required files (client.key, client.crt and ca.crt)
```

with rest-client:

```ruby
  url = 'https://localhost:3002/hook/test'
  response = RestClient::Resource.new(
    url,
    ssl_client_cert: OpenSSL::X509::Certificate.new(File.read('certs/client.crt')),
    ssl_client_key:  OpenSSL::PKey::RSA.new(File.read('certs/client.key')),
    ssl_ca_file: 'certs/ca.crt',
    verify_ssl: OpenSSL::SSL::VERIFY_PEER
  ).get({ "X-API-VERSION" => "v1" })

  JSON.parse(response.body)
```

or with curl for a better handshake debugging log:

```
curl --key certs/client.key --cert certs/client.crt --cacert certs/ca.crt  https://localhost:3001/hook/test --header "X-API-VERSION: v1" -v
```

```ruby
# check date:
  openssl x509 -noout -text -in certs/server.crt | grep -i -A2 validity

# check content
  openssl x509 -in certs/ca.crt -noout -text
  openssl rsa -in certs/ca.key -check
  openssl x509 -noout -text -in certs/server.crt
  openssl req -noout -text -in certs/server.csr

#verify cer with ca
  openssl verify -CAfile certs/ca.crt certs/server.crt
  openssl verify -CAfile certs/ca.crt certs/client.crt
```

Some error mess:

```ruby
# Khi server và client sử dụng 2 CA khác nhau
Errno::EPIPE (Broken pipe)
SSL_connect returned=1 errno=0 state=error: certificate verify failed (certificate signature failure)

# Khi client cert và key được ký bởi 2 CA khác nhau
OpenSSL::SSL::SSLError (SSL_CTX_use_PrivateKey: key values mismatch)

# client cert hoặc key không đúng format
OpenSSL::PKey::RSAError (Neither PUB key nor PRIV key: nested asn1 error)

# client không truyền client cert hoặc client key
OpenSSL error: error:1417C0C7:SSL routines:tls_process_client_certificate:peer did not return a certificate
```

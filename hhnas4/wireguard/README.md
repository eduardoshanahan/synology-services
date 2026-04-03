# WireGuard Client for nas-host

WireGuard VPN client to connect nas-host to the homelab WireGuard network.

## Network Configuration

- **nas-host WireGuard IP**: 10.0.0.10/24
- **VPS WireGuard IP**: 10.0.0.10/24
- **VPS Endpoint**: 203.0.113.10:51820

## Deployment

```bash
# Deploy to nas-host
./deploy.sh nas-host

# Or specify custom directory
./deploy.sh nas-host /volume1/docker/homelab/nas-host/wireguard
```

## Configuration

The deployment requires `.env.sops` in the private repo with:
- `WG_PRIVATE_KEY`: nas-host's WireGuard private key

The `wg0.conf` is generated from `wg0.conf.template` with the private key injected.

## Verification

```bash
# Check WireGuard status
ssh nas-host 'docker exec nas-host-wireguard wg show'

# Test connectivity to VPS
ssh nas-host 'docker exec nas-host-wireguard ping -c 3 10.0.0.10'

# Test connectivity to pi-node-a
ssh nas-host 'docker exec nas-host-wireguard ping -c 3 10.0.0.10'
```

## VPS Configuration

After deploying WireGuard on nas-host, you must add nas-host as a peer on the VPS:

1. Get nas-host's public key (derived from private key)
2. Add to VPS WireGuard configuration in `nix-vps-private/modules/vps-host.nix`:

```nix
{
  # nas-host
  publicKey = "<nas-host-public-key>";
  allowedIPs = [ "10.0.0.10/32" ];
}
```

3. Redeploy VPS to activate the peer configuration

## Troubleshooting

### Container won't start
- Check kernel modules: `lsmod | grep wireguard`
- Synology may require installing WireGuard kernel module
- Check container logs: `docker logs nas-host-wireguard`

### Connection not working
- Verify firewall on VPS allows UDP 51820
- Check peer configuration on VPS: `ssh vps-host 'sudo wg show'`
- Verify endpoint is reachable: `nc -zvu 203.0.113.10 51820`

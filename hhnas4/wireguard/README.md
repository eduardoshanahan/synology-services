# WireGuard Client for hhnas4

WireGuard VPN client to connect hhnas4 to the homelab WireGuard network.

## Network Configuration

- **hhnas4 WireGuard IP**: 10.100.0.4/24
- **VPS WireGuard IP**: 10.100.0.1/24
- **VPS Endpoint**: 57.128.171.12:51820

## Deployment

```bash
# Deploy to hhnas4
./deploy.sh hhnas4

# Or specify custom directory
./deploy.sh hhnas4 /volume1/docker/homelab/hhnas4/wireguard
```

## Configuration

The deployment requires `.env.sops` in the private repo with:
- `WG_PRIVATE_KEY`: hhnas4's WireGuard private key

The `wg0.conf` is generated from `wg0.conf.template` with the private key injected.

## Verification

```bash
# Check WireGuard status
ssh hhnas4 'docker exec hhnas4-wireguard wg show'

# Test connectivity to VPS
ssh hhnas4 'docker exec hhnas4-wireguard ping -c 3 10.100.0.1'

# Test connectivity to rpi-box-01
ssh hhnas4 'docker exec hhnas4-wireguard ping -c 3 10.100.0.2'
```

## VPS Configuration

After deploying WireGuard on hhnas4, you must add hhnas4 as a peer on the VPS:

1. Get hhnas4's public key (derived from private key)
2. Add to VPS WireGuard configuration in `nix-vps-private/modules/vps-01.nix`:

```nix
{
  # hhnas4
  publicKey = "<hhnas4-public-key>";
  allowedIPs = [ "10.100.0.4/32" ];
}
```

3. Redeploy VPS to activate the peer configuration

## Troubleshooting

### Container won't start
- Check kernel modules: `lsmod | grep wireguard`
- Synology may require installing WireGuard kernel module
- Check container logs: `docker logs hhnas4-wireguard`

### Connection not working
- Verify firewall on VPS allows UDP 51820
- Check peer configuration on VPS: `ssh vps-01 'sudo wg show'`
- Verify endpoint is reachable: `nc -zvu 57.128.171.12 51820`

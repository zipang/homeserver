# WORK IN PROGRESS

## 1. Public Domain & SSL (Cloudflare Migration)
We are moving DNS resolution to Cloudflare to enable the ACME DNS-01 challenge (for self-renewing SSL certificates) and to support wildcard subdomains for `zrok`.

### Tasks:
- [ ] **Manual: Cloudflare Setup**
    1. **Add Site**: Log in to Cloudflare, click "Add a Site" on the dashboard, and enter your domain name.
    2. **Select Plan**: Choose the "Free" plan at the bottom and click "Continue".
    3. **Review DNS**: Cloudflare will scan existing records. Verify them and click "Continue".
    4. **Change Nameservers**: 
        - Log in to Namecheap.
        - Go to your Domain List > Manage > Nameservers.
        - Change from "Namecheap BasicDNS" to "Custom DNS".
        - Enter the two nameservers provided by Cloudflare (e.g., `ashley.ns.cloudflare.com`).
    5. **Wait for Propagation**: It can take from 10 minutes to 24 hours for the change to be active.
    6. **Create API Token**: 
        - Go to `My Profile > API Tokens > Create Token`.
        - Use "Edit zone DNS" template.
        - Under "Zone Resources", select `Specific zone` and choose your domain.
        - Copy the token immediately (it's only shown once).
- [ ] **Secrets**: Store the Cloudflare API Token in `secrets/secrets.yaml` (managed via sops).
    - Key: `acme/cloudflare_token`
    - Format: `CLOUDFLARE_DNS_API_TOKEN=your_token_here`
- [x] **NixOS**: Implement `modules/system/acme.nix` with the DNS-01 challenge provider.
- [x] **Nginx**: Update `modules/services/nginx.nix` to use the ACME certificate.

## Current State
- Domain points to `<PUBLIC_IP>`.
- Port 80/443 are closed (Router/Firewall).
- ACME DNS-01 is the chosen path for SSL.

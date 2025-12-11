#!/bin/bash

echo "🔍 Monitoring SSL Certificate Status for test.nhameo.site"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

while true; do
    # Get certificate status
    STATUS=$(gcloud compute ssl-certificates describe alb1-ssl-cert --format="get(managed.status)" 2>/dev/null)
    DOMAIN_STATUS=$(gcloud compute ssl-certificates describe alb1-ssl-cert --format="get(managed.domainStatus)" 2>/dev/null)
    
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$TIMESTAMP] Certificate Status: $STATUS"
    echo "[$TIMESTAMP] Domain Status: $DOMAIN_STATUS"
    
    if [ "$STATUS" = "ACTIVE" ]; then
        echo ""
        echo "✅ SUCCESS! SSL Certificate is now ACTIVE!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌐 Testing HTTPS connection..."
        curl -I https://test.nhameo.site 2>&1 | head -15
        break
    fi
    
    echo "⏳ Still provisioning... checking again in 30 seconds"
    echo ""
    sleep 30
done

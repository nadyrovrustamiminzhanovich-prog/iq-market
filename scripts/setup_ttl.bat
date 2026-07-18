@echo off
echo ===================================================
echo   IQ-Market: Configuring Firestore TTL Policy
echo ===================================================
echo This script sets up a TTL policy for the "viewLogs" collection using the "createdAt" field.
echo Requires gcloud CLI to be installed and authorized.
echo.
gcloud firestore fields ttl-policies create --collection-group=viewLogs --field=createdAt
echo.
echo Configuration command sent. You can check policy status with:
echo gcloud firestore fields ttl-policies list --collection-group=viewLogs
pause

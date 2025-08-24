# Energy Grid Load Balancing System

A comprehensive smart contract system for managing energy grid load balancing using real-time smart meter data on the Stacks blockchain.

## Overview

This system provides a decentralized solution for energy grid management, featuring real-time monitoring, demand response coordination, peak load management, renewable energy integration, and grid stability monitoring.

## System Architecture

The system consists of five interconnected smart contracts:

### 1. Smart Meter Monitoring (`smart-meter-monitor.clar`)
- Real-time energy consumption tracking
- Smart meter data validation and storage
- Historical consumption analytics
- Meter registration and management

### 2. Demand Response Coordination (`demand-response.clar`)
- Automated demand response program management
- Consumer incentive distribution
- Load reduction event coordination
- Participation tracking and rewards

### 3. Peak Load Management (`peak-load-manager.clar`)
- Dynamic pricing based on grid demand
- Peak hour identification and management
- Load shedding coordination
- Price optimization algorithms

### 4. Renewable Energy Integration (`renewable-integration.clar`)
- Solar and wind energy production tracking
- Energy storage management
- Grid feed-in coordination
- Renewable energy certificate management

### 5. Grid Stability Monitor (`grid-stability.clar`)
- Real-time grid health monitoring
- Outage detection and prevention
- Load balancing automation
- Emergency response coordination

## Key Features

- **Real-time Monitoring**: Continuous tracking of energy consumption and production
- **Automated Response**: Smart contract-driven demand response and load balancing
- **Dynamic Pricing**: Market-based pricing that responds to grid conditions
- **Renewable Integration**: Seamless integration of renewable energy sources
- **Grid Stability**: Proactive monitoring and response to grid instabilities
- **Incentive Management**: Automated reward distribution for grid participation

## Data Types

### Energy Metrics
- `consumption`: Energy usage in kilowatt-hours (kWh)
- `production`: Energy generation in kWh
- `demand`: Real-time grid demand
- `price`: Dynamic energy pricing per kWh

### Grid Status
- `stability-score`: Grid health indicator (0-100)
- `load-factor`: Current load as percentage of capacity
- `renewable-percentage`: Renewable energy contribution

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Stacks wallet for deployment

### Installation
\`\`\`bash
npm install
clarinet check
\`\`\`

### Testing
\`\`\`bash
npm test
\`\`\`

### Deployment
\`\`\`bash
clarinet deploy
\`\`\`

## Contract Interactions

### Smart Meter Registration
```clarity
(contract-call? .smart-meter-monitor register-meter meter-id location-data)

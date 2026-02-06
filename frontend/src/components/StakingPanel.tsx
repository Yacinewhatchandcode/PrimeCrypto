import { useState } from 'react'
import './StakingPanel.css'

interface StakingPanelProps {
    isConnected: boolean
}

function StakingPanel({ isConnected }: StakingPanelProps) {
    const [amount, setAmount] = useState('')
    const [duration, setDuration] = useState('0')

    const durations = [
        { value: '0', label: 'No Lock', apy: '10%' },
        { value: '30', label: '30 Days', apy: '12%' },
        { value: '90', label: '90 Days', apy: '15%' },
        { value: '180', label: '180 Days', apy: '18%' },
        { value: '365', label: '1 Year', apy: '20%' },
    ]

    const selectedDuration = durations.find(d => d.value === duration)

    const handleStake = () => {
        if (!isConnected) {
            alert('Please connect your wallet first')
            return
        }
        console.log('Staking', amount, 'for', duration, 'days')
    }

    return (
        <section className="staking-panel">
            <h3 className="section-title">Stake PRIME</h3>

            <div className="staking-stats">
                <div className="staking-stat">
                    <span className="stat-value">2,500.00</span>
                    <span className="stat-label">Your Staked</span>
                </div>
                <div className="staking-stat">
                    <span className="stat-value">234.56</span>
                    <span className="stat-label">Rewards Earned</span>
                </div>
                <div className="staking-stat">
                    <span className="stat-value">3,750</span>
                    <span className="stat-label">Voting Power</span>
                </div>
            </div>

            <div className="staking-form">
                <div className="form-group">
                    <label>Amount to Stake</label>
                    <div className="input-with-max">
                        <input
                            type="number"
                            placeholder="0.00"
                            value={amount}
                            onChange={(e) => setAmount(e.target.value)}
                        />
                        <button className="max-btn" onClick={() => setAmount('1234.56')}>MAX</button>
                    </div>
                    <span className="balance">Balance: 1,234.56 PRIME</span>
                </div>

                <div className="form-group">
                    <label>Lock Duration</label>
                    <div className="duration-options">
                        {durations.map((d) => (
                            <button
                                key={d.value}
                                className={`duration-btn ${duration === d.value ? 'active' : ''}`}
                                onClick={() => setDuration(d.value)}
                            >
                                <span className="duration-label">{d.label}</span>
                                <span className="duration-apy">{d.apy} APY</span>
                            </button>
                        ))}
                    </div>
                </div>

                <div className="stake-summary">
                    <div className="summary-row">
                        <span>Selected APY</span>
                        <span className="text-prime">{selectedDuration?.apy}</span>
                    </div>
                    <div className="summary-row">
                        <span>Voting Multiplier</span>
                        <span>{duration === '365' ? '2.0x' : duration === '180' ? '1.5x' : duration === '90' ? '1.25x' : duration === '30' ? '1.08x' : '1.0x'}</span>
                    </div>
                    <div className="summary-row">
                        <span>Est. Yearly Rewards</span>
                        <span className="text-success">{amount ? (parseFloat(amount) * parseFloat(selectedDuration?.apy || '10') / 100).toFixed(2) : '0.00'} PRIME</span>
                    </div>
                </div>

                <button
                    className="btn btn-primary w-full stake-btn"
                    onClick={handleStake}
                    disabled={!amount || parseFloat(amount) <= 0}
                >
                    {isConnected ? 'Stake PRIME' : 'Connect Wallet to Stake'}
                </button>
            </div>
        </section>
    )
}

export default StakingPanel

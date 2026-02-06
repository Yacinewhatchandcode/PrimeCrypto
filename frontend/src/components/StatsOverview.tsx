import './StatsOverview.css'

interface Stat {
    label: string
    value: string
    change?: string
    trend?: 'up' | 'down'
}

function StatsOverview() {
    const stats: Stat[] = [
        { label: 'PRIME Price', value: '$0.0234', change: '+5.2%', trend: 'up' },
        { label: 'Market Cap', value: '$23.4M', change: '+3.1%', trend: 'up' },
        { label: 'Total Staked', value: '156.7M PRIME', change: '+12.5%', trend: 'up' },
        { label: 'Active Agents', value: '1,247', change: '+89', trend: 'up' },
        { label: 'Tasks Completed', value: '45,892', change: '+1,234 today', trend: 'up' },
        { label: 'Rewards Distributed', value: '2.3M PRIME', change: 'Last 24h', trend: 'up' },
    ]

    return (
        <section className="stats-overview">
            <h2 className="section-title">Overview</h2>

            <div className="stats-grid">
                {stats.map((stat, index) => (
                    <div key={index} className="stat-card animate-fade-in" style={{ animationDelay: `${index * 50}ms` }}>
                        <div className="stat-value">{stat.value}</div>
                        <div className="stat-label">{stat.label}</div>
                        {stat.change && (
                            <div className={`stat-change ${stat.trend}`}>
                                {stat.trend === 'up' ? '↑' : '↓'} {stat.change}
                            </div>
                        )}
                    </div>
                ))}
            </div>
        </section>
    )
}

export default StatsOverview

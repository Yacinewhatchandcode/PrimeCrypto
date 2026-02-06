import './AgentActivity.css'

interface Activity {
    id: string
    agent: string
    taskType: string
    reward: string
    time: string
    status: 'completed' | 'pending' | 'verified'
}

function AgentActivity() {
    const activities: Activity[] = [
        { id: '0x1a2b...3c4d', agent: 'CodeAgent-Alpha', taskType: 'Code Generation', reward: '125 PRIME', time: '2 min ago', status: 'completed' },
        { id: '0x5e6f...7g8h', agent: 'SecurityBot-01', taskType: 'Security Audit', reward: '450 PRIME', time: '5 min ago', status: 'completed' },
        { id: '0x9i0j...1k2l', agent: 'DataProcessor-X', taskType: 'Data Processing', reward: '28 PRIME', time: '8 min ago', status: 'verified' },
        { id: '0x3m4n...5o6p', agent: 'ResearchAgent-7', taskType: 'Oracle Data', reward: '75 PRIME', time: '12 min ago', status: 'completed' },
        { id: '0x7q8r...9s0t', agent: 'CodeAgent-Beta', taskType: 'Code Generation', reward: '200 PRIME', time: '15 min ago', status: 'pending' },
    ]

    const getStatusClass = (status: string) => {
        switch (status) {
            case 'completed': return 'status-completed'
            case 'verified': return 'status-verified'
            case 'pending': return 'status-pending'
            default: return ''
        }
    }

    return (
        <section className="agent-activity">
            <div className="section-header">
                <h3 className="section-title">Agent Activity</h3>
                <span className="live-badge">
                    <span className="live-dot"></span>
                    Live
                </span>
            </div>

            <div className="activity-list">
                {activities.map((activity, index) => (
                    <div
                        key={activity.id}
                        className="activity-item animate-fade-in"
                        style={{ animationDelay: `${index * 100}ms` }}
                    >
                        <div className="activity-icon">🤖</div>
                        <div className="activity-details">
                            <div className="activity-agent">{activity.agent}</div>
                            <div className="activity-task">
                                <span className="task-type">{activity.taskType}</span>
                                <span className="task-id">{activity.id}</span>
                            </div>
                        </div>
                        <div className="activity-meta">
                            <div className="activity-reward">{activity.reward}</div>
                            <div className="activity-time">{activity.time}</div>
                        </div>
                        <div className={`activity-status ${getStatusClass(activity.status)}`}>
                            {activity.status}
                        </div>
                    </div>
                ))}
            </div>

            <button className="btn btn-secondary w-full view-all-btn">
                View All Activity
            </button>
        </section>
    )
}

export default AgentActivity

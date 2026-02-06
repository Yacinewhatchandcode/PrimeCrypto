import { useState } from 'react'
import './GovernancePanel.css'

interface GovernancePanelProps {
    isConnected: boolean
}

interface Proposal {
    id: number
    title: string
    description: string
    proposer: string
    forVotes: string
    againstVotes: string
    status: 'active' | 'passed' | 'rejected' | 'pending'
    endsIn: string
}

function GovernancePanel({ isConnected }: GovernancePanelProps) {
    const [activeTab, setActiveTab] = useState<'active' | 'past'>('active')

    const proposals: Proposal[] = [
        {
            id: 1,
            title: 'Increase Oracle Reward Pool by 5M PRIME',
            description: 'Proposal to allocate additional tokens to the oracle reward pool to incentivize more validators.',
            proposer: '0x1a2b...3c4d',
            forVotes: '12.5M',
            againstVotes: '3.2M',
            status: 'active',
            endsIn: '2 days'
        },
        {
            id: 2,
            title: 'Carbon Offset Integration with Toucan Protocol',
            description: 'Integrate carbon offset tracking and automated purchases via Toucan Protocol.',
            proposer: '0x5e6f...7g8h',
            forVotes: '8.1M',
            againstVotes: '1.5M',
            status: 'active',
            endsIn: '5 days'
        },
        {
            id: 3,
            title: 'Add New Task Type: Research Analysis',
            description: 'Enable agents to submit research analysis tasks with dedicated reward tier.',
            proposer: '0x9i0j...1k2l',
            forVotes: '15.2M',
            againstVotes: '2.1M',
            status: 'passed',
            endsIn: 'Executed'
        },
    ]

    const handleVote = (proposalId: number, support: boolean) => {
        if (!isConnected) {
            alert('Please connect your wallet to vote')
            return
        }
        console.log(`Voting ${support ? 'FOR' : 'AGAINST'} proposal ${proposalId}`)
    }

    const getStatusBadge = (status: string) => {
        const badges: Record<string, { class: string; label: string }> = {
            active: { class: 'badge-active', label: 'Active' },
            passed: { class: 'badge-passed', label: 'Passed' },
            rejected: { class: 'badge-rejected', label: 'Rejected' },
            pending: { class: 'badge-pending', label: 'Pending' },
        }
        return badges[status] || badges.pending
    }

    return (
        <section className="governance-panel panel">
            <div className="governance-header">
                <h3 className="section-title">Governance</h3>

                <div className="governance-tabs">
                    <button
                        className={`tab ${activeTab === 'active' ? 'active' : ''}`}
                        onClick={() => setActiveTab('active')}
                    >
                        Active Proposals
                    </button>
                    <button
                        className={`tab ${activeTab === 'past' ? 'active' : ''}`}
                        onClick={() => setActiveTab('past')}
                    >
                        Past Proposals
                    </button>
                </div>
            </div>

            <div className="proposals-list">
                {proposals
                    .filter(p => activeTab === 'active' ? p.status === 'active' : p.status !== 'active')
                    .map((proposal, index) => (
                        <div
                            key={proposal.id}
                            className="proposal-card animate-fade-in"
                            style={{ animationDelay: `${index * 100}ms` }}
                        >
                            <div className="proposal-header">
                                <span className={`status-badge ${getStatusBadge(proposal.status).class}`}>
                                    {getStatusBadge(proposal.status).label}
                                </span>
                                <span className="proposal-id">#{proposal.id}</span>
                            </div>

                            <h4 className="proposal-title">{proposal.title}</h4>
                            <p className="proposal-description">{proposal.description}</p>

                            <div className="proposal-votes">
                                <div className="vote-bar">
                                    <div
                                        className="vote-for"
                                        style={{
                                            width: `${(parseFloat(proposal.forVotes) / (parseFloat(proposal.forVotes) + parseFloat(proposal.againstVotes))) * 100}%`
                                        }}
                                    ></div>
                                </div>
                                <div className="vote-counts">
                                    <span className="vote-for-count">✓ {proposal.forVotes} FOR</span>
                                    <span className="vote-against-count">✗ {proposal.againstVotes} AGAINST</span>
                                </div>
                            </div>

                            <div className="proposal-footer">
                                <div className="proposal-meta">
                                    <span>Proposed by {proposal.proposer}</span>
                                    <span className="ends-in">{proposal.endsIn}</span>
                                </div>

                                {proposal.status === 'active' && (
                                    <div className="vote-actions">
                                        <button
                                            className="btn btn-vote-for"
                                            onClick={() => handleVote(proposal.id, true)}
                                        >
                                            Vote For
                                        </button>
                                        <button
                                            className="btn btn-vote-against"
                                            onClick={() => handleVote(proposal.id, false)}
                                        >
                                            Vote Against
                                        </button>
                                    </div>
                                )}
                            </div>
                        </div>
                    ))}
            </div>

            <div className="governance-actions">
                <button className="btn btn-primary">
                    Create Proposal
                </button>
                <span className="proposal-requirement">
                    Requires 10,000 PRIME to create a proposal
                </span>
            </div>
        </section>
    )
}

export default GovernancePanel

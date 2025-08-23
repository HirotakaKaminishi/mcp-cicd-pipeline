#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hybrid CI/CD Monitoring System
Integrates legacy MCP API monitoring with modern Docker monitoring
Provides comprehensive visibility across both deployment systems
"""

import requests
import json
import time
import subprocess
import os
import threading
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Any

@dataclass
class HealthStatus:
    """Health status data structure"""
    service: str
    status: str
    response_time: Optional[float]
    timestamp: str
    details: Dict[str, Any]

@dataclass
class DeploymentInfo:
    """Deployment information data structure"""
    method: str
    status: str
    timestamp: str
    commit_sha: str
    release_path: Optional[str]
    container_count: Optional[int]
    details: Dict[str, Any]

class HybridMonitoringSystem:
    def __init__(self, config=None):
        self.config = config or {
            'mcp_server_url': 'http://192.168.111.200:8080',
            'ssh_host': '192.168.111.200',
            'ssh_key_path': 'auth_organized/keys_configs/mcp_docker_key',
            'legacy_path': '/root/mcp_project',
            'docker_path': '/var/deployment',
            'monitoring_interval': 30,  # seconds
            'health_timeout': 10,       # seconds
            'history_retention': 24     # hours
        }
        
        self.health_history: List[HealthStatus] = []
        self.deployment_history: List[DeploymentInfo] = []
        self.is_monitoring = False
        
        print(f"[INIT] Hybrid Monitoring System initialized")
        print(f"   MCP Server: {self.config['mcp_server_url']}")
        print(f"   SSH Host: {self.config['ssh_host']}")
        print(f"   Monitoring Interval: {self.config['monitoring_interval']}s")

    def execute_mcp_command(self, command, timeout=60):
        """Execute command via MCP API"""
        url = self.config['mcp_server_url']
        payload = {
            'jsonrpc': '2.0',
            'method': 'execute_command',
            'params': {'command': command},
            'id': 1
        }
        try:
            start_time = time.time()
            response = requests.post(url, json=payload, timeout=timeout)
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                if 'result' in result:
                    return {
                        'success': True,
                        'response_time': response_time,
                        'data': result['result']
                    }
            return {
                'success': False,
                'response_time': response_time,
                'error': f'HTTP {response.status_code}'
            }
        except Exception as e:
            return {
                'success': False,
                'response_time': None,
                'error': str(e)
            }

    def execute_ssh_command(self, command, timeout=30):
        """Execute command via SSH"""
        ssh_cmd = [
            'ssh', '-i', self.config['ssh_key_path'],
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'ConnectTimeout=10',
            f"root@{self.config['ssh_host']}",
            command
        ]
        
        try:
            start_time = time.time()
            result = subprocess.run(
                ssh_cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            response_time = time.time() - start_time
            
            return {
                'success': result.returncode == 0,
                'response_time': response_time,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'response_time': timeout,
                'error': 'SSH command timeout'
            }
        except Exception as e:
            return {
                'success': False,
                'response_time': None,
                'error': str(e)
            }

    def check_mcp_api_health(self):
        """Check MCP API system health"""
        timestamp = datetime.now().isoformat()
        
        # Basic MCP server connectivity
        mcp_result = self.execute_mcp_command('echo "MCP API health check"', timeout=self.config['health_timeout'])
        
        details = {
            'connectivity': mcp_result['success'],
            'response_time': mcp_result.get('response_time'),
        }
        
        if mcp_result['success']:
            # Get system information
            system_info = self.execute_mcp_command('uptime && free -h | head -2', timeout=10)
            if system_info['success']:
                details['system_info'] = system_info['data'].get('stdout', '').strip()
            
            # Check legacy application status
            app_status = self.execute_mcp_command(f'ls -la {self.config["legacy_path"]}/current/', timeout=10)
            if app_status['success']:
                details['legacy_app'] = 'present'
                
            # Check deployment log
            log_check = self.execute_mcp_command(f'tail -1 {self.config["legacy_path"]}/deployment.log 2>/dev/null', timeout=10)
            if log_check['success'] and log_check['data'].get('stdout'):
                details['last_deployment'] = log_check['data']['stdout'].strip()

        status = 'healthy' if mcp_result['success'] else 'unhealthy'
        
        return HealthStatus(
            service='mcp_api',
            status=status,
            response_time=mcp_result.get('response_time'),
            timestamp=timestamp,
            details=details
        )

    def check_docker_system_health(self):
        """Check Docker system health"""
        timestamp = datetime.now().isoformat()
        
        # SSH connectivity check
        ssh_result = self.execute_ssh_command('echo "SSH Docker health check"')
        
        details = {
            'ssh_connectivity': ssh_result['success'],
            'ssh_response_time': ssh_result.get('response_time'),
        }
        
        if ssh_result['success']:
            # Docker daemon status
            docker_check = self.execute_ssh_command('docker --version && docker info | head -5')
            if docker_check['success']:
                details['docker_daemon'] = 'running'
                details['docker_info'] = docker_check['stdout'][:200]
            
            # Container status
            container_check = self.execute_ssh_command(f'cd {self.config["docker_path"]} && docker compose ps')
            if container_check['success']:
                details['containers'] = container_check['stdout']
                # Count running containers
                running_containers = len([line for line in container_check['stdout'].split('\n') if 'Up' in line])
                details['running_container_count'] = running_containers
            
            # Resource usage
            resource_check = self.execute_ssh_command('docker stats --no-stream --format "table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}" | head -5')
            if resource_check['success']:
                details['resource_usage'] = resource_check['stdout']
                
            # Recent deployment log
            log_check = self.execute_ssh_command(f'tail -1 {self.config["docker_path"]}/deployment.log 2>/dev/null')
            if log_check['success'] and log_check['stdout'].strip():
                details['last_deployment'] = log_check['stdout'].strip()

        status = 'healthy' if ssh_result['success'] else 'unhealthy'
        
        return HealthStatus(
            service='docker_system',
            status=status,
            response_time=ssh_result.get('response_time'),
            timestamp=timestamp,
            details=details
        )

    def check_service_endpoints(self):
        """Check external service endpoints"""
        timestamp = datetime.now().isoformat()
        
        endpoints = [
            ('main_website', f"http://{self.config['ssh_host']}"),
            ('health_endpoint', f"http://{self.config['ssh_host']}/health"),
            ('service_endpoint', f"http://{self.config['ssh_host']}/service"),
            ('mcp_api_direct', f"http://{self.config['ssh_host']}:8080"),
        ]
        
        endpoint_results = {}
        total_response_time = 0
        healthy_endpoints = 0
        
        for name, url in endpoints:
            try:
                start_time = time.time()
                response = requests.get(url, timeout=self.config['health_timeout'])
                response_time = time.time() - start_time
                
                endpoint_results[name] = {
                    'status': 'healthy' if response.status_code == 200 else 'unhealthy',
                    'response_time': response_time,
                    'status_code': response.status_code,
                    'content_length': len(response.content) if response.content else 0
                }
                
                if response.status_code == 200:
                    healthy_endpoints += 1
                    total_response_time += response_time
                    
            except Exception as e:
                endpoint_results[name] = {
                    'status': 'unhealthy',
                    'error': str(e)
                }
        
        overall_status = 'healthy' if healthy_endpoints > 0 else 'unhealthy'
        avg_response_time = total_response_time / healthy_endpoints if healthy_endpoints > 0 else None
        
        details = {
            'endpoints': endpoint_results,
            'healthy_count': healthy_endpoints,
            'total_count': len(endpoints),
            'health_percentage': (healthy_endpoints / len(endpoints)) * 100
        }
        
        return HealthStatus(
            service='service_endpoints',
            status=overall_status,
            response_time=avg_response_time,
            timestamp=timestamp,
            details=details
        )

    def check_github_runner_status(self):
        """Check GitHub Runner status (if available)"""
        timestamp = datetime.now().isoformat()
        
        # Check runner service status
        service_check = self.execute_ssh_command(
            'systemctl is-active actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service 2>/dev/null'
        )
        
        details = {
            'service_status': service_check.get('stdout', '').strip() if service_check['success'] else 'unknown'
        }
        
        # Check runner processes
        process_check = self.execute_ssh_command('ps aux | grep -E "Runner|actions" | grep -v grep | wc -l')
        if process_check['success']:
            details['process_count'] = int(process_check['stdout'].strip() or '0')
        
        # Check recent activity
        if service_check['success'] and 'active' in service_check.get('stdout', ''):
            log_check = self.execute_ssh_command(
                'journalctl -u actions.runner.HirotakaKaminishi-mcp-cicd-pipeline.mcp-server-runner.service --since "1 hour ago" | tail -1'
            )
            if log_check['success']:
                details['recent_activity'] = log_check['stdout'][:200]
        
        status = 'healthy' if details.get('process_count', 0) > 0 else 'unhealthy'
        
        return HealthStatus(
            service='github_runner',
            status=status,
            response_time=service_check.get('response_time'),
            timestamp=timestamp,
            details=details
        )

    def comprehensive_health_check(self):
        """Perform comprehensive health check across all systems"""
        print(f"[CHECK] [{datetime.now().strftime('%H:%M:%S')}] Performing comprehensive health check...")
        
        # Run all health checks
        health_checks = [
            self.check_mcp_api_health(),
            self.check_docker_system_health(),
            self.check_service_endpoints(),
            self.check_github_runner_status()
        ]
        
        # Store in history
        self.health_history.extend(health_checks)
        
        # Cleanup old history
        self.cleanup_old_history()
        
        return health_checks

    def get_deployment_status(self):
        """Get current deployment status from both systems"""
        deployments = []
        
        # MCP API deployment status
        mcp_deploy = self.execute_mcp_command(
            f'tail -3 {self.config["legacy_path"]}/deployment.log 2>/dev/null | grep -E "(successful|failed)"'
        )
        
        if mcp_deploy['success'] and mcp_deploy['data'].get('stdout'):
            last_mcp = mcp_deploy['data']['stdout'].strip().split('\n')[-1]
            deployments.append(DeploymentInfo(
                method='mcp_api',
                status='success' if 'successful' in last_mcp else 'failed',
                timestamp=last_mcp.split(':')[0] if ':' in last_mcp else datetime.now().isoformat(),
                commit_sha=self.extract_commit_sha(last_mcp),
                release_path=None,
                container_count=None,
                details={'log_entry': last_mcp}
            ))
        
        # Docker deployment status
        docker_deploy = self.execute_ssh_command(
            f'tail -3 {self.config["docker_path"]}/deployment.log 2>/dev/null | grep -E "(successful|failed)"'
        )
        
        if docker_deploy['success'] and docker_deploy['stdout'].strip():
            last_docker = docker_deploy['stdout'].strip().split('\n')[-1]
            
            # Get container count
            container_count_result = self.execute_ssh_command(
                f'cd {self.config["docker_path"]} && docker compose ps -q | wc -l'
            )
            container_count = int(container_count_result['stdout'].strip()) if container_count_result['success'] else None
            
            deployments.append(DeploymentInfo(
                method='docker_compose',
                status='success' if 'successful' in last_docker else 'failed',
                timestamp=last_docker.split(':')[0] if ':' in last_docker else datetime.now().isoformat(),
                commit_sha=self.extract_commit_sha(last_docker),
                release_path=None,
                container_count=container_count,
                details={'log_entry': last_docker}
            ))
        
        return deployments

    def extract_commit_sha(self, log_entry):
        """Extract commit SHA from deployment log entry"""
        import re
        sha_match = re.search(r'[a-f0-9]{8,40}', log_entry)
        return sha_match.group() if sha_match else 'unknown'

    def cleanup_old_history(self):
        """Remove old history entries beyond retention period"""
        cutoff_time = datetime.now() - timedelta(hours=self.config['history_retention'])
        cutoff_str = cutoff_time.isoformat()
        
        self.health_history = [h for h in self.health_history if h.timestamp > cutoff_str]
        self.deployment_history = [d for d in self.deployment_history if d.timestamp > cutoff_str]

    def generate_health_report(self):
        """Generate comprehensive health report"""
        current_health = self.comprehensive_health_check()
        deployments = self.get_deployment_status()
        
        print("\n" + "="*80)
        print("🚀 HYBRID CI/CD SYSTEM HEALTH REPORT")
        print("="*80)
        print(f"📅 Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔄 Monitoring Interval: {self.config['monitoring_interval']}s")
        print(f"📊 History Retention: {self.config['history_retention']}h")
        
        print("\n📋 SYSTEM HEALTH STATUS:")
        print("-" * 40)
        
        for health in current_health:
            status_emoji = "✅" if health.status == 'healthy' else "❌"
            rt_info = f" ({health.response_time:.2f}s)" if health.response_time else ""
            print(f"{status_emoji} {health.service.upper()}: {health.status.upper()}{rt_info}")
            
            # Show key details
            if health.service == 'service_endpoints':
                healthy = health.details.get('healthy_count', 0)
                total = health.details.get('total_count', 0)
                print(f"   📊 Endpoints: {healthy}/{total} healthy ({health.details.get('health_percentage', 0):.1f}%)")
                
            elif health.service == 'docker_system':
                container_count = health.details.get('running_container_count', 0)
                print(f"   🐳 Containers: {container_count} running")
                
            elif health.service == 'github_runner':
                process_count = health.details.get('process_count', 0)
                print(f"   🏃 Processes: {process_count} active")
        
        print("\n🚀 DEPLOYMENT STATUS:")
        print("-" * 40)
        
        if deployments:
            for deploy in deployments:
                status_emoji = "✅" if deploy.status == 'success' else "❌"
                method_name = deploy.method.replace('_', ' ').title()
                print(f"{status_emoji} {method_name}: {deploy.status.upper()}")
                print(f"   📝 Commit: {deploy.commit_sha[:8]}...")
                print(f"   🕒 Time: {deploy.timestamp}")
                if deploy.container_count:
                    print(f"   🐳 Containers: {deploy.container_count}")
        else:
            print("   ℹ️  No recent deployment information found")
        
        print("\n🌐 SERVICE ENDPOINTS:")
        print("-" * 40)
        endpoints_health = next((h for h in current_health if h.service == 'service_endpoints'), None)
        if endpoints_health:
            for name, info in endpoints_health.details.get('endpoints', {}).items():
                status_emoji = "✅" if info.get('status') == 'healthy' else "❌"
                endpoint_name = name.replace('_', ' ').title()
                rt_info = f" ({info.get('response_time', 0):.2f}s)" if info.get('response_time') else ""
                print(f"{status_emoji} {endpoint_name}: {info.get('status', 'unknown').upper()}{rt_info}")
        
        print("\n📈 PERFORMANCE METRICS:")
        print("-" * 40)
        
        # Calculate average response times from recent history
        if len(self.health_history) > 1:
            recent_health = self.health_history[-10:]  # Last 10 checks
            avg_times = {}
            
            for service_name in ['mcp_api', 'docker_system', 'service_endpoints']:
                service_times = [h.response_time for h in recent_health 
                               if h.service == service_name and h.response_time]
                if service_times:
                    avg_times[service_name] = sum(service_times) / len(service_times)
            
            for service, avg_time in avg_times.items():
                print(f"📊 {service.replace('_', ' ').title()} Avg Response: {avg_time:.2f}s")
        
        print("\n💡 RECOMMENDATIONS:")
        print("-" * 40)
        
        # Generate recommendations based on health status
        recommendations = self.generate_recommendations(current_health)
        for rec in recommendations:
            print(f"   🔧 {rec}")
        
        if not recommendations:
            print("   ✨ All systems operating optimally!")
        
        print("\n" + "="*80)
        
        return {
            'health_status': [asdict(h) for h in current_health],
            'deployments': [asdict(d) for d in deployments],
            'timestamp': datetime.now().isoformat()
        }

    def generate_recommendations(self, health_checks):
        """Generate actionable recommendations based on health status"""
        recommendations = []
        
        for health in health_checks:
            if health.status != 'healthy':
                if health.service == 'mcp_api':
                    recommendations.append("Check MCP server connectivity and API endpoints")
                elif health.service == 'docker_system':
                    recommendations.append("Verify Docker daemon status and container health")
                elif health.service == 'service_endpoints':
                    healthy_pct = health.details.get('health_percentage', 0)
                    if healthy_pct < 50:
                        recommendations.append("Multiple service endpoints down - check network and services")
                    else:
                        recommendations.append("Some service endpoints unhealthy - investigate specific services")
                elif health.service == 'github_runner':
                    recommendations.append("GitHub Runner not active - check runner service and configuration")
            
            # Performance recommendations
            if health.response_time and health.response_time > 5.0:
                recommendations.append(f"High response time for {health.service} - investigate performance")
        
        return recommendations

    def start_continuous_monitoring(self):
        """Start continuous monitoring in background thread"""
        if self.is_monitoring:
            print("⚠️  Monitoring already running")
            return
        
        self.is_monitoring = True
        print(f"🎯 Starting continuous monitoring (interval: {self.config['monitoring_interval']}s)")
        print("   Press Ctrl+C to stop")
        
        def monitoring_loop():
            while self.is_monitoring:
                try:
                    self.comprehensive_health_check()
                    time.sleep(self.config['monitoring_interval'])
                except KeyboardInterrupt:
                    self.is_monitoring = False
                    break
                except Exception as e:
                    print(f"❌ Monitoring error: {e}")
                    time.sleep(5)  # Wait before retrying
        
        monitoring_thread = threading.Thread(target=monitoring_loop, daemon=True)
        monitoring_thread.start()
        
        try:
            # Keep main thread alive and show periodic reports
            while self.is_monitoring:
                time.sleep(300)  # Show report every 5 minutes
                if self.is_monitoring:
                    print(f"\n📊 [{datetime.now().strftime('%H:%M:%S')}] Periodic Health Summary:")
                    recent_health = self.health_history[-4:] if len(self.health_history) >= 4 else self.health_history
                    for health in recent_health:
                        status_emoji = "✅" if health.status == 'healthy' else "❌"
                        print(f"   {status_emoji} {health.service}: {health.status}")
        except KeyboardInterrupt:
            self.is_monitoring = False
            print("\n🛑 Monitoring stopped by user")

    def export_metrics(self, format='json'):
        """Export monitoring metrics"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'config': self.config,
            'current_health': [asdict(h) for h in self.health_history[-4:]] if self.health_history else [],
            'deployment_history': [asdict(d) for d in self.deployment_history],
            'summary': {
                'total_health_checks': len(self.health_history),
                'total_deployments': len(self.deployment_history),
                'monitoring_duration': self.config['history_retention']
            }
        }
        
        if format == 'json':
            return json.dumps(metrics, indent=2)
        else:
            return metrics

def main():
    """Main CLI interface"""
    import sys
    
    if len(sys.argv) < 2:
        print("""
🔧 Hybrid CI/CD Monitoring System

Usage: python hybrid-monitoring.py <command> [options]

Commands:
  health                    Perform single health check
  report                    Generate comprehensive health report
  monitor                   Start continuous monitoring
  export [json]             Export monitoring data
  
Examples:
  python hybrid-monitoring.py health
  python hybrid-monitoring.py report
  python hybrid-monitoring.py monitor
  python hybrid-monitoring.py export json > metrics.json
        """)
        return
    
    command = sys.argv[1].lower()
    
    # Initialize monitoring system
    monitor = HybridMonitoringSystem()
    
    try:
        if command == 'health':
            health_checks = monitor.comprehensive_health_check()
            print(f"\n📋 Health Check Results:")
            for health in health_checks:
                status_emoji = "✅" if health.status == 'healthy' else "❌"
                print(f"{status_emoji} {health.service}: {health.status}")
                
        elif command == 'report':
            report = monitor.generate_health_report()
            
        elif command == 'monitor':
            monitor.start_continuous_monitoring()
            
        elif command == 'export':
            format_type = sys.argv[2] if len(sys.argv) > 2 else 'json'
            metrics = monitor.export_metrics(format_type)
            print(metrics)
            
        else:
            print(f"❌ Unknown command: {command}")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n🛑 Operation cancelled by user")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
// Configuration
const API_BASE_URL = 'http://localhost:3000/api';

// State management
let eventSource = null;
let eventCount = 0;
let isListening = false;

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeEventListeners();
    setDefaultDates();
});

function initializeEventListeners() {
    // Query tab
    document.getElementById('queryBtn').addEventListener('click', executeQuery);
    document.getElementById('useCurrentTime').addEventListener('click', setEndDateToNow);
    
    // Events tab
    document.getElementById('startListening').addEventListener('click', startEventListening);
    document.getElementById('stopListening').addEventListener('click', stopEventListening);
    document.getElementById('clearEvents').addEventListener('click', clearEvents);
    
    // Create tab
    document.getElementById('createResourceForm').addEventListener('submit', createResource);
    
    // Set current timestamp for create form
    document.getElementById('timestamp').value = getCurrentDateTime();
}

function setDefaultDates() {
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    
    document.getElementById('startDate').value = formatDateTimeLocal(yesterday);
    document.getElementById('endDate').value = formatDateTimeLocal(now);
}

function setEndDateToNow() {
    document.getElementById('endDate').value = getCurrentDateTime();
}

function getCurrentDateTime() {
    return formatDateTimeLocal(new Date());
}

function formatDateTimeLocal(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
}

// Query functionality
async function executeQuery() {
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;
    
    if (!startDate || !endDate) {
        showAlert('Please select both start and end dates', 'danger');
        return;
    }
    
    const startTimestamp = new Date(startDate).getTime();
    const endTimestamp = new Date(endDate).getTime();
    
    if (startTimestamp >= endTimestamp) {
        showAlert('Start date must be before end date', 'danger');
        return;
    }
    
    const queryBtn = document.getElementById('queryBtn');
    const spinner = document.getElementById('querySpinner');
    
    try {
        queryBtn.disabled = true;
        spinner.classList.remove('d-none');
        
        // This endpoint needs to be implemented in your backend
        // For now, we'll show a mock implementation structure
        const response = await fetch(`${API_BASE_URL}/read?start=${startTimestamp}&end=${endTimestamp}`);
        
        if (!response.ok) {
            throw new Error(`Query failed: ${response.statusText}`);
        }
        
        const data = await response.json();
        displayQueryResults(data);
        
    } catch (error) {
        console.error('Query error:', error);
        showAlert(`Query failed: ${error.message}`, 'danger');
    } finally {
        queryBtn.disabled = false;
        spinner.classList.add('d-none');
    }
}

function displayQueryResults(results) {
    const resultsDiv = document.getElementById('queryResults');
    const container = document.getElementById('resultsContainer');
    
    if (!results || results.length === 0) {
        container.innerHTML = '<p class="text-muted">No resources found for the selected time range.</p>';
        resultsDiv.style.display = 'block';
        return;
    }
    
    let html = `
        <div class="mb-2">
            <strong>${results.length}</strong> resource(s) found
        </div>
        <div class="table-responsive">
            <table class="table table-hover">
                <thead>
                    <tr>
                        <th>PID</th>
                        <th>URI</th>
                        <th>Hash</th>
                        <th>Timestamp</th>
                        <th>Owners</th>
                    </tr>
                </thead>
                <tbody>
    `;
    
    results.forEach(resource => {
        const date = new Date(parseInt(resource.timestamp));
        const owners = Array.isArray(resource.owners) ? resource.owners : JSON.parse(resource.owners || '[]');
        
        html += `
            <tr>
                <td><code>${escapeHtml(resource.pid)}</code></td>
                <td>${escapeHtml(resource.uri)}</td>
                <td><code class="text-truncate d-inline-block" style="max-width: 150px;">${escapeHtml(resource.hash)}</code></td>
                <td>${date.toLocaleString()}</td>
                <td>
                    ${owners.map(owner => `<span class="badge bg-info me-1">${escapeHtml(owner)}</span>`).join('')}
                </td>
            </tr>
        `;
    });
    
    html += `
                </tbody>
            </table>
        </div>
    `;
    
    container.innerHTML = html;
    resultsDiv.style.display = 'block';
}

// Event listening functionality
function startEventListening() {
    if (isListening) return;
    
    // This would typically use Server-Sent Events (SSE) or WebSocket
    // Since your backend uses regular event listeners, we'll simulate polling
    isListening = true;
    eventCount = 0;
    
    document.getElementById('startListening').disabled = true;
    document.getElementById('stopListening').disabled = false;
    document.getElementById('eventStatus').textContent = 'Listening...';
    document.getElementById('eventStatus').classList.remove('bg-secondary');
    document.getElementById('eventStatus').classList.add('bg-success');
    
    updateEventCount();
    
    // Connect to SSE endpoint
    eventSource = new EventSource(`${API_BASE_URL}/events/stream`);
    
    eventSource.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            
            if (data.type === 'connected') {
                console.log('Connected to event stream');
                return;
            }
            
            addEventToDisplay(data);
        } catch (error) {
            console.error('Error parsing event:', error);
        }
    };
    
    eventSource.onerror = (error) => {
        console.error('EventSource error:', error);
        showAlert('Event stream disconnected. Trying to reconnect...', 'warning');
        
        // Auto-reconnect after 5 seconds
        setTimeout(() => {
            if (isListening) {
                stopEventListening();
                startEventListening();
            }
        }, 5000);
    };
}

function stopEventListening() {
    if (!isListening) return;
    
    isListening = false;
    
    if (eventSource) {
        eventSource.close();
        eventSource = null;
    }
    
    document.getElementById('startListening').disabled = false;
    document.getElementById('stopListening').disabled = true;
    document.getElementById('eventStatus').textContent = 'Not listening';
    document.getElementById('eventStatus').classList.remove('bg-success');
    document.getElementById('eventStatus').classList.add('bg-secondary');
}

function clearEvents() {
    eventCount = 0;
    document.getElementById('eventsContainer').innerHTML = `
        <div class="text-center text-muted py-5">
            <p>No events yet. Start listening to see real-time blockchain events.</p>
        </div>
    `;
    updateEventCount();
}

function addEventToDisplay(event) {
    const container = document.getElementById('eventsContainer');
    
    // Remove placeholder text
    if (eventCount === 0) {
        container.innerHTML = '';
    }
    
    const eventDiv = document.createElement('div');
    eventDiv.className = 'event-item';
    
    const timestamp = new Date().toLocaleTimeString();
    
    eventDiv.innerHTML = `
        <div class="event-header">
            <strong>${escapeHtml(event.eventName)}</strong>
            <span class="event-time">${timestamp}</span>
        </div>
        <pre class="event-payload">${JSON.stringify(event.payload, null, 2)}</pre>
    `;
    
    container.insertBefore(eventDiv, container.firstChild);
    eventCount++;
    updateEventCount();
    
    // Keep only last 50 events
    while (container.children.length > 50) {
        container.removeChild(container.lastChild);
    }
}

function updateEventCount() {
    document.getElementById('eventCount').textContent = `${eventCount} event(s) received`;
}

// Create resource functionality
async function createResource(e) {
    e.preventDefault();
    
    const pid = document.getElementById('pid').value;
    const uri = document.getElementById('uri').value;
    const hash = document.getElementById('hash').value;
    const timestamp = new Date(document.getElementById('timestamp').value).getTime();
    const ownersStr = document.getElementById('owners').value;
    const owners = ownersStr.split(',').map(o => o.trim()).filter(o => o);

    console.log('Creating resource with:', { pid, uri, hash, timestamp, owners });
    
    const spinner = document.getElementById('createSpinner');
    const submitBtn = e.target.querySelector('button[type="submit"]');
    
    try {
        submitBtn.disabled = true;
        spinner.classList.remove('d-none');
        
        const response = await fetch(`${API_BASE_URL}/create`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                pid,
                uri,
                hash,
                timestamp,
                owners
            })
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to create resource');
        }
        
        const result = await response.json();
        
        showCreateSuccess(`Resource created successfully! PID: ${result.pid}`);
        document.getElementById('createResourceForm').reset();
        document.getElementById('timestamp').value = getCurrentDateTime();
        
    } catch (error) {
        console.error('Create error:', error);
        showCreateError(error.message);
    } finally {
        submitBtn.disabled = false;
        spinner.classList.add('d-none');
    }
}

// Utility functions
function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    const container = document.querySelector('.main-content .p-4');
    container.insertBefore(alertDiv, container.firstChild);
    
    setTimeout(() => {
        alertDiv.remove();
    }, 5000);
}

function showCreateSuccess(message) {
    const successDiv = document.getElementById('createSuccess');
    successDiv.textContent = message;
    successDiv.classList.remove('d-none');
    document.getElementById('createError').classList.add('d-none');
    
    setTimeout(() => {
        successDiv.classList.add('d-none');
    }, 5000);
}

function showCreateError(message) {
    const errorDiv = document.getElementById('createError');
    errorDiv.textContent = message;
    errorDiv.classList.remove('d-none');
    document.getElementById('createSuccess').classList.add('d-none');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
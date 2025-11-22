document.addEventListener('DOMContentLoaded', () => {
    initFileManager();
});

/**
 * Initialize the file manager:
 * - Load file list
 * - Setup upload functionality
 * - Setup drag and drop
 */
function initFileManager() {
    loadFiles();
    setupUploadButton();
    setupDragAndDrop();
}

/**
 * Setup upload button functionality
 */
function setupUploadButton() {
    const fileInput = document.getElementById('file');
    const uploadButton = document.getElementById('uploadButton');

    if (!fileInput || !uploadButton) return;

    // Button click opens file dialog
    uploadButton.addEventListener('click', () => {
        fileInput.click();
    });

    // Handle file selection
    fileInput.addEventListener('change', async (event) => {
        const file = event.target.files[0];
        if (file) {
            await handleSingleFileUpload(file);
        }
    });
}

/**
 * Setup drag and drop functionality
 */
function setupDragAndDrop() {
    const dragDropArea = document.getElementById('dragDropArea');
    if (!dragDropArea) return;

    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dragDropArea.addEventListener(eventName, preventDefaults, false);
        document.body.addEventListener(eventName, preventDefaults, false);
    });

    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
        dragDropArea.addEventListener(eventName, () => dragDropArea.classList.add('dragover'), false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        dragDropArea.addEventListener(eventName, () => dragDropArea.classList.remove('dragover'), false);
    });

    // Handle dropped files
    dragDropArea.addEventListener('drop', async (e) => {
        const files = e.dataTransfer.files;
        if (files.length > 0) {
            if (files.length > 1) {
                showWarning(translations['select_one_file']);
                return;
            }
            await handleSingleFileUpload(files[0]);
        }
    });
}

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

/**
 * Handle single file upload for both button and drag-drop
 */
async function handleSingleFileUpload(file) {
    const progress = document.getElementById('progress');
    const fileInput = document.getElementById('file');

    const maxFileSize = fileSizeLimit * 1024 * 1024;
    if (file.size > maxFileSize) {
        const fileSizeMB = (file.size / 1024 / 1024).toFixed(2);
        showError(`${translations['file_too_large']} (${fileSizeMB} MB)`);
        if (fileInput) fileInput.value = '';
        return;
    }

    showCircularProgress();

    try {
        await uploadFile(file, progress);
        await loadFiles();
    } catch (error) {
        showError(`${translations["upload_error"]}: ${error.message}`);
    } finally {
        // Hide circular progress and clear file input
        hideCircularProgress();
        if (fileInput) fileInput.value = '';
    }
}/**
 * Upload a single file to the server
 * @param {File} file 
 * @param {HTMLProgressElement} progress 
 */
async function uploadFile(file, progress) {
    return new Promise((resolve, reject) => {
        const formData = new FormData();
        formData.append('file', file, file.name);

        const xhr = new XMLHttpRequest();
        xhr.open('POST', '/upload');

        xhr.upload.onprogress = (event) => {
            if (event.lengthComputable) {
                const percentage = Math.round((event.loaded / event.total) * 100);
                updateCircularProgress(percentage);
                if (progress) progress.value = percentage;
            }
        };

        xhr.onload = () => {
            if (xhr.status === 200) {
                updateCircularProgress(100);
                if (progress) progress.value = 100;
                resolve();
            } else {
                reject(new Error(`HTTP ${xhr.status}: ${xhr.statusText}`));
            }
        };

        xhr.onerror = () => {
            showAlert(translations['server_not_available']);
        };

        xhr.ontimeout = () => {
            showAlert(translations['timeout_error']);
        };

        xhr.timeout = 30000;
        xhr.send(formData);
    });
}

var fileSizeLimit = 30;

var translations = {
    "ok": "OK",
    "cancel": "Cancel",
    "delete_file": "Confirm File Deletion",
    "delete_confirmation": "This file will be permanently removed.",
    "delete_error": "Delete Error",
    "file_too_large": `File size is too large! Maximum file size is ${fileSizeLimit} MB.`,
    "select_one_file": "Please select only one file at a time.",
    "upload_error": "Upload Error",
    "server_not_available": "Server not available.",
    "timeout_error": "The upload is taking too long."
}

/**
 * Merge translations, keeping defaults for null/undefined values
 * @param {Object} defaultTranslations - Default translation values
 * @param {Object} serverTranslations - Translations from server
 * @returns {Object} Merged translations
 */
function mergeTranslations(defaultTranslations, serverTranslations) {
    const merged = { ...defaultTranslations };

    for (const key in serverTranslations) {
        if (serverTranslations.hasOwnProperty(key)) {
            const serverValue = serverTranslations[key];
            if (serverValue != null && serverValue !== '') {
                merged[key] = serverValue;
            }
        }
    }

    return merged;
}

/**
 * Load the file list from the server and render it in the table
 */
async function loadFiles() {
    try {
        const response = await fetch('/list');
        const data = await response.json();
        files = data.files || [];
        fileSizeLimit = data.fileSizeLimit || 30;
        if (data.translations) {
            translations = mergeTranslations(translations, data.translations);
        }
        const tbody = document.getElementById('fileTableBody');
        if (!tbody) return;
        tbody.innerHTML = '';
        files.forEach(file => tbody.appendChild(createTableRow(file)));
    } catch (error) {
        console.error('Error loading files:', error);
    }
}

/**
 * Create a table row element for a file
 * @param {Object} file 
 * @returns {HTMLTableRowElement}
 */
function createTableRow(file) {
    const tr = document.createElement('tr');

    // Icon cell
    const iconCell = document.createElement('td');
    iconCell.className = 'file-icon-cell';
    const fileIcon = createFileTypeIcon(file.path);
    iconCell.appendChild(fileIcon);

    // Main content cell
    const mainCell = document.createElement('td');
    mainCell.className = 'file-row';

    // File info container (title + size)
    const fileInfo = document.createElement('div');
    fileInfo.className = 'file-info';

    const titleDiv = document.createElement('div');
    titleDiv.className = 'file-title';
    titleDiv.textContent = file.title;
    titleDiv.title = file.title; // Tooltip for truncated text

    const sizeDiv = document.createElement('div');
    sizeDiv.className = 'file-size';
    sizeDiv.textContent = formatFileSize(file.size);

    fileInfo.appendChild(titleDiv);
    fileInfo.appendChild(sizeDiv);

    // Actions container with icon buttons
    const actionsDiv = document.createElement('div');
    actionsDiv.className = 'file-actions';

    const downloadBtn = createIconButton('download', () => downloadFile(file.path), 'download');
    const deleteBtn = createIconButton('delete', () => removeFile(file.path), 'delete');

    actionsDiv.appendChild(deleteBtn);
    actionsDiv.appendChild(downloadBtn);

    mainCell.appendChild(fileInfo);
    mainCell.appendChild(actionsDiv);

    tr.appendChild(iconCell);
    tr.appendChild(mainCell);

    return tr;
}

/**
 * Create file type icon based on file extension
 * @param {string} filePath 
 * @returns {HTMLElement}
 */
function createFileTypeIcon(filePath) {
    const extension = filePath.split('.').pop().toLowerCase();
    const isAudio = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'].includes(extension);

    // Create container div
    const container = document.createElement('div');
    container.className = 'file-type-icon-container';

    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', '14');
    svg.setAttribute('height', '14');
    svg.setAttribute('class', 'file-type-icon');

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');

    if (isAudio) {
        // Music/melody icon
        path.setAttribute('d', 'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z');
        container.classList.add('audio-icon');
    } else {
        // Video icon
        path.setAttribute('d', 'M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z');
        container.classList.add('video-icon');
    }

    svg.appendChild(path);
    container.appendChild(svg);
    return container;
}

/**
 * Check if file size is within allowed limit
 * @param {File} file 
 * @returns {boolean}
 */
function isFileSizeValid(file) {
    const maxFileSize = 30 * 1024 * 1024; // 30MB in bytes
    return file.size <= maxFileSize;
}

/**
 * Format file size to human readable format
 * @param {number} bytes 
 * @returns {string}
 */
function formatFileSize(bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes === 0) return '0 B';
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return parseFloat((bytes / Math.pow(1024, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * Create an icon button with SVG icon
 * @param {string} iconType - 'download' or 'delete'
 * @param {Function} onClick 
 * @param {string} type
 * @returns {HTMLButtonElement}
 */
function createIconButton(iconType, onClick, type = '') {
    const button = document.createElement('button');
    button.className = `icon-button ${type}`;
    button.onclick = onClick;
    button.title = type === 'download' ? 'Download' : type === 'delete' ? 'Delete' : '';

    // Create SVG icon based on type
    const svg = createSVGIcon(iconType);
    button.appendChild(svg);

    return button;
}

/**
 * Create SVG icon element
 * @param {string} iconType - 'download' or 'delete'
 * @returns {SVGElement}
 */
function createSVGIcon(iconType) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', '20');
    svg.setAttribute('height', '20');

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');

    if (iconType === 'download') {
        // Download icon
        path.setAttribute('d', 'M12 15.577l4.618-4.618 1.414 1.414L12 18.405l-6.032-6.032 1.414-1.414L12 15.577zM12 13V2h2v11h-2zM4 17h16v2H4v-2z');
    } else if (iconType === 'delete') {
        // Delete/Trash icon  
        path.setAttribute('d', 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z');
    }

    svg.appendChild(path);
    return svg;
}

/**
 * Trigger file download via browser
 * @param {string} path 
 */
function downloadFile(path) {
    window.location.href = `/download?path=${encodeURIComponent(path)}`;
}

/**
 * Remove file from server and reload the table
 * @param {string} path 
 */
async function removeFile(path) {
    const filename = path.split('/').pop() || 'file';

    showConfirmation(
        translations['delete_file'],
        translations['delete_confirmation'],
        async () => {
            try {
                const response = await fetch(`/remove?path=${encodeURIComponent(path)}`);
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
                }
                await loadFiles();
            } catch (error) {
                showError(`${translations["delete_error"]}: ${error.message}`);
            }
        }
    );
}

/**
 * Show circular progress overlay
 * @param {string} label - Progress label text
 */
function showCircularProgress() {
    const overlay = document.getElementById('progressOverlay');
    const progressLabel = document.getElementById('progressLabel');

    if (overlay && progressLabel) {
        overlay.classList.add('active');
        updateCircularProgress(0);
    }
}

/**
 * Hide circular progress overlay
 */
function hideCircularProgress() {
    const overlay = document.getElementById('progressOverlay');
    if (overlay) {
        overlay.classList.remove('active');
    }
}

/**
 * Update circular progress percentage
 * @param {number} percentage - Progress percentage (0-100)
 */
function updateCircularProgress(percentage) {
    const circle = document.getElementById('progressCircle');
    const text = document.getElementById('progressText');

    if (circle && text) {
        const circumference = 314.16;
        const offset = circumference - (percentage / 100) * circumference;

        circle.style.strokeDashoffset = offset;
        text.textContent = `${percentage}%`;
    }
}

/**
 * Show custom modal dialog
 * @param {string} title - Dialog title
 * @param {string} message - Dialog message
 * @param {string} type - Dialog type (optional)
 * @param {Array} buttons - Array of button objects: [{text: 'OK', action: function}]
 */
function showDialog(title, message, type = 'info', buttons = null) {
    const overlay = document.getElementById('modalOverlay');
    const titleEl = document.getElementById('modalTitle');
    const messageEl = document.getElementById('modalMessage');
    const actionsEl = document.getElementById('modalActions');

    if (!overlay || !titleEl || !messageEl || !actionsEl) {
        alert(`${title}: ${message}`);
        return;
    }

    // Set title and message
    titleEl.textContent = title;
    messageEl.textContent = message;

    // Clear existing buttons
    actionsEl.innerHTML = '';

    // Add buttons
    const defaultButtons = (Array.isArray(buttons) ? buttons : null) || [
        { text: 'OK', action: () => hideDialog() }
    ];

    defaultButtons.forEach(button => {
        const btn = document.createElement('button');
        btn.className = 'modal-button';
        btn.textContent = button.text;
        btn.onclick = () => {
            if (button.action) button.action();
            hideDialog();
        };
        actionsEl.appendChild(btn);
    });

    // Show dialog
    overlay.classList.add('active');

    // Close on overlay click
    overlay.onclick = (e) => {
        if (e.target === overlay) {
            hideDialog();
        }
    };

    // Close on Escape key
    const handleEscape = (e) => {
        if (e.key === 'Escape') {
            hideDialog();
            document.removeEventListener('keydown', handleEscape);
        }
    };
    document.addEventListener('keydown', handleEscape);
}

/**
 * Hide modal dialog
 */
function hideDialog() {
    const overlay = document.getElementById('modalOverlay');
    if (overlay) {
        overlay.classList.remove('active');
        overlay.onclick = null;
    }
}

/**
 * Show simple alert dialog (replaces native alert)
 * @param {string} message - Alert message
 */
function showAlert(message) {
    showDialog('Info', message, 'info', [
        { text: translations['ok'] || 'OK', action: null }
    ]);
}

/**
 * Show warning dialog
 * @param {string} message - Warning message
 */
function showWarning(message) {
    showDialog('Warning', message, 'warning', [
        { text: translations['ok'] || 'OK', action: null }
    ]);
}

/**
 * Show error dialog
 * @param {string} message - Error message
 */
function showError(message) {
    showDialog('Error', message, 'error', [
        { text: translations['ok'] || 'OK', action: null }
    ]);
}

/**
 * Show confirmation dialog
 * @param {string} title - Dialog title
 * @param {string} message - Dialog message
 * @param {Function} onConfirm - Callback when user confirms
 * @param {Function} onCancel - Callback when user cancels (optional)
 */
function showConfirmation(title, message, onConfirm, onCancel = null) {
    const buttons = [
        {
            text: translations['cancel'] || 'Cancel',
            action: onCancel
        },
        {
            text: translations['ok'] || 'OK',
            action: onConfirm
        }
    ];

    showDialog(title, message, 'warning', buttons);
}

/**
 * Get dummy files for testing
 * @returns {Array}
 */
function getDummyFiles() {
    return [
        {
            title: "Bohemian Rhapsody - Queen.mp3",
            path: "/music/bohemian_rhapsody.mp3",
            size: 5240000
        },
        {
            title: "Imagine - John Lennon.mp3",
            path: "/music/imagine.mp3",
            size: 3560000
        },
        {
            title: "Hotel California - Eagles.mp3",
            path: "/music/hotel_california.mp3",
            size: 4180000
        },
        {
            title: "Stairway to Heaven - Led Zeppelin.mp3",
            path: "/music/stairway_to_heaven.mp3",
            size: 8320000
        },
        {
            title: "Sweet Child O' Mine - Guns N' Roses.mp3",
            path: "/music/sweet_child_o_mine.mp3",
            size: 5670000
        },
        {
            title: "Purple Haze - Jimi Hendrix.mp3",
            path: "/music/purple_haze.mp3",
            size: 2890000
        },
        {
            title: "Billie Jean - Michael Jackson.mp4",
            path: "/videos/billie_jean.mp4",
            size: 45800000
        },
        {
            title: "Thriller - Michael Jackson.mp4",
            path: "/videos/thriller.mp4",
            size: 52400000
        },
        {
            title: "Thunderstruck - AC/DC.mp3",
            path: "/music/thunderstruck.mp3",
            size: 4920000
        },
        {
            title: "Smells Like Teen Spirit - Nirvana.mp3",
            path: "/music/smells_like_teen_spirit.mp3",
            size: 5020000
        },
        {
            title: "Uptown Funk - Bruno Mars.mp3",
            path: "/music/uptown_funk.mp3",
            size: 4340000
        },
        {
            title: "Shape of You - Ed Sheeran.mp3",
            path: "/music/shape_of_you.mp3",
            size: 3850000
        },
        {
            title: "Bad Guy - Billie Eilish.mp3",
            path: "/music/bad_guy.mp3",
            size: 3200000
        },
        {
            title: "Someone You Loved - Lewis Capaldi.mp3",
            path: "/music/someone_you_loved.mp3",
            size: 3920000
        },
        {
            title: "Blinding Lights - The Weeknd.mp3",
            path: "/music/blinding_lights.mp3",
            size: 3610000
        }
    ];
}
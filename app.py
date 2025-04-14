from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
import tempfile
from PyPDF2 import PdfReader, PdfWriter
from pdf2image import convert_from_path
from docx import Document
from io import BytesIO

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configuration
UPLOAD_FOLDER = tempfile.mkdtemp()
ALLOWED_EXTENSIONS = {'pdf'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB limit

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
@app.route('/api/process-pdf', methods=['POST'])
def process_pdf():
    try:
        # Check if file was uploaded
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400
        
        file = request.files['file']
        
        # Validate file
        if file.filename == '':
            return jsonify({'error': 'No selected file'}), 400
        
        if file and allowed_file(file.filename):
            filename = secure_filename(file.filename)
            temp_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(temp_path)
            
            operation = request.form.get('operation', 'compress')
            
            try:
                if operation == 'compress':
                    # PDF Compression
                    compression_level = request.form.get('compression_level', 'medium')
                    output_buffer = compress_pdf(temp_path, compression_level)
                    output_filename = f"compressed_{filename}"
                    mimetype = 'application/pdf'
                    
                elif operation == 'convert':
                    # PDF Conversion
                    target_format = request.form.get('target_format', 'docx')
                    if target_format == 'docx':
                        output_buffer = convert_pdf_to_docx(temp_path)
                        output_filename = f"{filename.split('.')[0]}.docx"
                        mimetype = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                    elif target_format in ['jpg', 'png']:
                        output_buffer = convert_pdf_to_image(temp_path, target_format)
                        output_filename = f"{filename.split('.')[0]}.{target_format}"
                        mimetype = f'image/{target_format}'
                    else:
                        return jsonify({'error': 'Unsupported conversion format'}), 400
                else:
                    return jsonify({'error': 'Invalid operation'}), 400
                
                # Clean up the temp file
                os.remove(temp_path)
                
                # Return the processed file
                return send_file(
                    output_buffer,
                    mimetype=mimetype,
                    as_attachment=True,
                    download_name=output_filename
                )
                
            except Exception as e:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
                return jsonify({'error': str(e)}), 500
        
        return jsonify({'error': 'Invalid file type. Only PDF files are allowed.'}), 400
    
    except Exception as e:
        return jsonify({'error': 'Internal server error', 'message': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

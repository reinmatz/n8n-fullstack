#!/usr/bin/env python3
"""
Simple PDF generator for test data using reportlab
Install: pip install reportlab
"""

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import cm
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
    from reportlab.lib import colors
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
except ImportError:
    print("ERROR: reportlab not installed")
    print("Install with: pip install reportlab")
    exit(1)

def create_test_pdf():
    # Create PDF
    pdf_file = "sample_document.pdf"
    doc = SimpleDocTemplate(pdf_file, pagesize=A4,
                            rightMargin=2*cm, leftMargin=2*cm,
                            topMargin=2*cm, bottomMargin=2*cm)

    # Container for the 'Flowable' objects
    elements = []

    # Define styles
    styles = getSampleStyleSheet()
    title_style = styles['Title']
    heading1_style = styles['Heading1']
    heading2_style = styles['Heading2']
    normal_style = styles['Normal']

    # Title
    elements.append(Paragraph("Technische Dokumentation: RAG-Systeme", title_style))
    elements.append(Spacer(1, 0.5*cm))

    # Einleitung
    elements.append(Paragraph("Einleitung", heading1_style))
    elements.append(Spacer(1, 0.3*cm))

    intro_text = """
    Retrieval-Augmented Generation (RAG) ist eine moderne Architektur für Large Language Models (LLMs),
    die externe Wissensdatenbanken mit generativen Modellen kombiniert. Diese Dokumentation beschreibt
    die Kernkonzepte, Implementierungen und Best Practices für RAG-Systeme.
    """
    elements.append(Paragraph(intro_text, normal_style))
    elements.append(Spacer(1, 0.5*cm))

    # Motivation
    elements.append(Paragraph("Motivation", heading2_style))
    elements.append(Spacer(1, 0.3*cm))

    motivation_text = """
    Traditionelle LLMs leiden unter mehreren Einschränkungen:<br/>
    • Halluzinationen bei fehlenden Informationen<br/>
    • Veraltetes Wissen aufgrund des festen Trainingsdatums<br/>
    • Keine Quellenangaben für generierte Antworten<br/>
    • Schwierigkeiten bei domänenspezifischem Wissen<br/><br/>
    RAG-Systeme adressieren diese Probleme durch die Integration einer Retrieval-Komponente.
    """
    elements.append(Paragraph(motivation_text, normal_style))
    elements.append(Spacer(1, 0.5*cm))

    # Page break
    elements.append(PageBreak())

    # Architektur
    elements.append(Paragraph("Architektur", heading1_style))
    elements.append(Spacer(1, 0.3*cm))

    arch_text = """
    Ein vollständiges RAG-System besteht aus folgenden Hauptkomponenten:<br/><br/>
    <b>1. Dokumenten-Ingestion</b><br/>
    • Upload-Interface für verschiedene Dateiformate (PDF, DOCX, TXT)<br/>
    • Parsing und Strukturierung der Inhalte<br/>
    • Chunking-Strategie zur Aufteilung in verarbeitbare Segmente<br/><br/>
    <b>2. Vektordatenbank</b><br/>
    • Speicherung von Embeddings<br/>
    • Effiziente Similaritätssuche (HNSW, IVF)<br/>
    • Metadaten-Filterung<br/><br/>
    <b>3. Retrieval-Pipeline</b><br/>
    • Query-Expansion für bessere Trefferquote<br/>
    • Hybrid-Suche (Vector + BM25)<br/>
    • Reranking der Top-K Ergebnisse
    """
    elements.append(Paragraph(arch_text, normal_style))
    elements.append(Spacer(1, 0.5*cm))

    # Table: Embedding-Modelle
    elements.append(PageBreak())
    elements.append(Paragraph("Embedding-Modelle Vergleich", heading1_style))
    elements.append(Spacer(1, 0.3*cm))

    table_data = [
        ['Modell', 'Dimensionen', 'Sprachen', 'MTEB Score', 'Lizenz'],
        ['bge-m3', '1024', '100+', '66.1', 'MIT'],
        ['e5-large-v2', '1024', '100+', '64.5', 'MIT'],
        ['multilingual-e5-base', '768', '100+', '61.5', 'MIT'],
        ['all-MiniLM-L6-v2', '384', 'EN', '58.8', 'Apache 2.0']
    ]

    table = Table(table_data, colWidths=[5*cm, 3*cm, 2.5*cm, 3*cm, 3*cm])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.grey),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 10),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 1, colors.black)
    ]))
    elements.append(table)
    elements.append(Spacer(1, 0.5*cm))

    # Best Practices
    elements.append(PageBreak())
    elements.append(Paragraph("Best Practices", heading1_style))
    elements.append(Spacer(1, 0.3*cm))

    bp_text = """
    <b>1. Metadaten-Management</b><br/>
    Jeder Chunk sollte umfangreiche Metadaten enthalten: document_id, filename, page_number,
    section, created_at, tags, version.<br/><br/>

    <b>2. PII-Filterung</b><br/>
    Sensible Daten müssen vor der Speicherung gefiltert werden: E-Mail-Adressen, Telefonnummern,
    IBAN/Kreditkartennummern, Sozialversicherungsnummern.<br/><br/>

    <b>3. Hybrid-Retrieval</b><br/>
    Kombination von Vektor- und Keyword-Suche (BM25) mit Reciprocal Rank Fusion (RRF).<br/><br/>

    <b>4. Zitationssystem</b><br/>
    LLM-Prompts sollten verpflichtende Quellenangaben fordern mit Markern wie [1], [2], etc.
    """
    elements.append(Paragraph(bp_text, normal_style))
    elements.append(Spacer(1, 0.5*cm))

    # Zusammenfassung
    elements.append(PageBreak())
    elements.append(Paragraph("Zusammenfassung", heading1_style))
    elements.append(Spacer(1, 0.3*cm))

    summary_text = """
    RAG-Systeme bieten eine leistungsstarke Lösung für wissensintensive LLM-Anwendungen.
    Die Kombination aus Retrieval und Generation ermöglicht:<br/><br/>
    • Aktuelle Informationen ohne Retraining<br/>
    • Quellenbasierte Antworten<br/>
    • Domain-spezifisches Wissen<br/>
    • Reduzierte Halluzinationen<br/><br/>
    <b>Kernempfehlungen:</b><br/>
    1. Semantisches Chunking für bessere Kontexterhaltung<br/>
    2. Hybrid-Retrieval (Vector + BM25) für Robustheit<br/>
    3. Verpflichtende Zitationen im LLM-Prompt<br/>
    4. Umfassendes Monitoring und Logging
    """
    elements.append(Paragraph(summary_text, normal_style))
    elements.append(Spacer(1, 1*cm))

    # Footer
    footer_text = """
    <i>Version: 1.0 | Letzte Aktualisierung: 9. November 2025 |
    Autor: RAG System Documentation Team</i>
    """
    elements.append(Paragraph(footer_text, normal_style))

    # Build PDF
    doc.build(elements)
    print(f"✓ PDF created: {pdf_file}")
    return pdf_file

if __name__ == "__main__":
    create_test_pdf()

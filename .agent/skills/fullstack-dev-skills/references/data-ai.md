# Data & AI Engineering

Data processing, ML pipelines, LLM prompt engineering, RAG, and fine-tuning.

## Pandas (DataFrame Operations)

```python
import pandas as pd

# Vectorized operations (fast) over iterrows (slow)
df['total'] = df['price'] * df['quantity']

# Method chaining
result = (
    df.pipe(clean_data)
      .query('status == "active"')
      .groupby('category')
      .agg(total=('amount', 'sum'), count=('id', 'count'))
      .sort_values('total', ascending=False)
)
```

| Pattern | When |
|---------|------|
| Vectorized ops | Always prefer over loops |
| `.pipe()` | Chain transformations |
| `.query()` | Readable filtering |
| `pd.Categorical` | Repeated string values (memory savings) |

## Apache Spark / PySpark

| Area | Pattern |
|------|---------|
| Partitioning | Partition by date/key for query efficiency |
| Caching | `.cache()` / `.persist()` for reused DataFrames |
| Broadcast | `broadcast()` small tables for joins |
| UDFs | Avoid when possible; use built-in functions |
| Spark SQL | Prefer SQL API for complex analytics |

## ML Pipeline

| Stage | Tools |
|-------|-------|
| Experiment Tracking | MLflow, Weights & Biases |
| Feature Store | Feast, Tecton |
| Training | PyTorch, TensorFlow, scikit-learn |
| Serving | TorchServe, TF Serving, BentoML |
| Monitoring | Evidently, WhyLabs |

## Prompt Engineering

| Technique | Description |
|-----------|-------------|
| Zero-shot | Direct instruction, no examples |
| Few-shot | 2-5 examples demonstrating desired output |
| Chain-of-thought | "Think step by step" for reasoning |
| System prompt | Set persona, constraints, output format |
| Structured output | JSON mode, function calling |

### Prompt Template
```
You are a {role} expert.

## Task
{task_description}

## Rules
- {constraint_1}
- {constraint_2}

## Examples
Input: {example_input}
Output: {example_output}

## Input
{actual_input}
```

## RAG Architecture

```
Query → Embed → Vector Search → Retrieve Chunks → Augment Prompt → LLM → Response
```

| Component | Options |
|-----------|---------|
| Embedding | OpenAI ada-002, Cohere embed-v3, sentence-transformers |
| Vector DB | Pinecone, Weaviate, Qdrant, pgvector, Chroma |
| Chunking | Fixed-size, recursive, semantic, document-aware |
| Retrieval | Top-K similarity, hybrid (vector + keyword), re-ranking |

## Fine-Tuning

| Method | VRAM | Use Case |
|--------|------|----------|
| Full fine-tune | High (40GB+) | Maximum quality, small models |
| LoRA | Medium (16GB) | Parameter-efficient, most use cases |
| QLoRA | Low (8GB) | Budget-constrained, large models |

| Parameter | Guidance |
|-----------|----------|
| Learning rate | 1e-5 to 5e-5 (start low) |
| Epochs | 1-3 (watch for overfitting) |
| Batch size | Largest that fits in memory |
| Eval strategy | Hold-out test set + human evaluation |

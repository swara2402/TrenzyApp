"""FashionCLIP integration for fashion-specific image/text embeddings.

Uses Marqo's FashionCLIP model fine-tuned on ~800K fashion products.
Loaded via open_clip (not transformers AutoModel — the Marqo custom wrapper
crashes with torch.device('meta') under PyTorch >= 2.x on macOS).

The model identifier and expected embedding dimension are defined in
``ml_config`` — never hardcode ``512`` anywhere else.
"""

from __future__ import annotations

import logging
from typing import Optional, Union
import numpy as np
import torch
from PIL import Image

from ..ml_config import FASHIONCLIP_MODEL_NAME, EMBEDDING_DIM, validate_model_embedding_dim

logger = logging.getLogger(__name__)

# Export canonical model name for imports
FASHIONCLIP_MODEL = FASHIONCLIP_MODEL_NAME

# Canonical hub path for open_clip
_OPEN_CLIP_HUB = f"hf-hub:{FASHIONCLIP_MODEL_NAME}"


class FashionCLIPModel:
    """FashionCLIP model for fashion-specific embeddings.

    Loaded via ``open_clip`` (not ``transformers.AutoModel``).
    The Marqo model ships a custom ``open_clip``-based wrapper that does
    not support the standard ``transformers`` AutoModel interface reliably
    on all platforms.
    """

    def __init__(
        self,
        model_name: str = FASHIONCLIP_MODEL_NAME,
        device: Optional[str] = None,
    ):
        """Initialize FashionCLIP model.

        Args:
            model_name: Hugging Face model name (used to build hf-hub: path)
            device: Device to run on (cuda/cpu). Auto-detected if None.
        """
        import open_clip  # deferred so tests can mock before import

        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        hub_path = f"hf-hub:{model_name}"
        logger.info("Loading FashionCLIP via open_clip: %s on %s", hub_path, self.device)

        self._model, _, self._preprocess = open_clip.create_model_and_transforms(hub_path)
        self._tokenizer = open_clip.get_tokenizer(hub_path)

        self._model = self._model.to(self.device)
        self._model.eval()
        self.model_name = model_name

        # Determine embedding dimension from a dry-run rather than from config
        # attributes that may differ across open_clip model variants.
        with torch.no_grad():
            _probe = Image.new("RGB", (224, 224))
            _t = self._preprocess(_probe).unsqueeze(0).to(self.device)
            _feat = self._model.encode_image(_t)
        self.embedding_dim = int(_feat.shape[1])

        # Hard-fail if the live model dimension disagrees with the system constant.
        validate_model_embedding_dim(self.embedding_dim)
        logger.info("FashionCLIP loaded successfully. Embedding dim: %d", self.embedding_dim)

    # ------------------------------------------------------------------
    # Public encoding API
    # ------------------------------------------------------------------

    def encode_image(
        self,
        image: Union[str, Image.Image],
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode an image into a FashionCLIP embedding.

        Args:
            image: Image path or PIL Image.
            normalize: L2-normalise the output vector (default True).

        Returns:
            1-D numpy array of shape ``(embedding_dim,)``.
        """
        if isinstance(image, str):
            image = Image.open(image).convert("RGB")

        tensor = self._preprocess(image).unsqueeze(0).to(self.device)
        with torch.no_grad():
            feat = self._model.encode_image(tensor)
            if normalize:
                feat = feat / feat.norm(dim=-1, keepdim=True)
        return feat[0].cpu().numpy()

    def encode_text(
        self,
        text: str,
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode a text string into a FashionCLIP embedding.

        Args:
            text: Text string.
            normalize: L2-normalise the output vector (default True).

        Returns:
            1-D numpy array of shape ``(embedding_dim,)``.
        """
        tokens = self._tokenizer([text]).to(self.device)
        with torch.no_grad():
            feat = self._model.encode_text(tokens)
            if normalize:
                feat = feat / feat.norm(dim=-1, keepdim=True)
        return feat[0].cpu().numpy()

    def encode_batch_images(
        self,
        images: list[Union[str, Image.Image]],
        batch_size: int = 32,
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode multiple images in batches.

        Args:
            images: List of image paths or PIL Images.
            batch_size: Batch size for encoding.
            normalize: L2-normalise each output vector.

        Returns:
            2-D numpy array of shape ``(N, embedding_dim)``.
        """
        pil_images = [
            Image.open(img).convert("RGB") if isinstance(img, str) else img
            for img in images
        ]

        embeddings: list[np.ndarray] = []
        for start in range(0, len(pil_images), batch_size):
            batch_pil = pil_images[start : start + batch_size]
            batch_t = torch.stack([self._preprocess(img) for img in batch_pil]).to(self.device)
            with torch.no_grad():
                feat = self._model.encode_image(batch_t)
                if normalize:
                    feat = feat / feat.norm(dim=-1, keepdim=True)
            embeddings.append(feat.cpu().numpy())

        return np.concatenate(embeddings, axis=0)

    def encode_batch_texts(
        self,
        texts: list[str],
        batch_size: int = 32,
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode multiple texts in batches.

        Args:
            texts: List of text strings.
            batch_size: Batch size for encoding.
            normalize: L2-normalise each output vector.

        Returns:
            2-D numpy array of shape ``(N, embedding_dim)``.
        """
        embeddings: list[np.ndarray] = []
        for start in range(0, len(texts), batch_size):
            chunk = texts[start : start + batch_size]
            tokens = self._tokenizer(chunk).to(self.device)
            with torch.no_grad():
                feat = self._model.encode_text(tokens)
                if normalize:
                    feat = feat / feat.norm(dim=-1, keepdim=True)
            embeddings.append(feat.cpu().numpy())

        return np.concatenate(embeddings, axis=0)

    def compute_similarity(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray,
    ) -> float:
        """Compute cosine similarity between two embeddings.

        Assumes both vectors are already L2-normalised (as produced by
        ``encode_image`` / ``encode_text`` with ``normalize=True``).

        Args:
            embedding1: First embedding (L2-normalised).
            embedding2: Second embedding (L2-normalised).

        Returns:
            Cosine similarity in [-1, 1].
        """
        return float(np.dot(embedding1, embedding2))
        
    def encode_combined(
        self,
        image: Union[str, Image.Image],
        text: str,
        image_weight: float = 0.6,
        text_weight: float = 0.4,
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode both image and text into a combined embedding.
        
        Combined embedding calculation:
            combined = normalized(image_weight * image_embedding + text_weight * text_embedding)
        
        Args:
            image: Image path or PIL Image
            text: Text string to encode
            image_weight: Weight for image embedding (default 0.6)
            text_weight: Weight for text embedding (default 0.4)
            normalize: L2-normalise the output vector (default True)

        Returns:
            1-D numpy array of shape ``(embedding_dim,)``
        """
        # Get individual embeddings (both already normalized if normalize=True)
        image_emb = self.encode_image(image, normalize=False)
        text_emb = self.encode_text(text, normalize=False)
        
        # Combine with weights
        combined = image_weight * image_emb + text_weight * text_emb
        
        if normalize:
            combined = combined / np.linalg.norm(combined)
            
        return combined
        
    def encode_batch_combined(
        self,
        images: list[Union[str, Image.Image]],
        texts: list[str],
        image_weight: float = 0.6,
        text_weight: float = 0.4,
        batch_size: int = 32,
        normalize: bool = True,
    ) -> np.ndarray:
        """Encode batches of image-text pairs into combined embeddings.

        Args:
            images: List of image paths or PIL Images
            texts: List of text strings (must match length of images)
            image_weight: Weight for image embedding (default 0.6)
            text_weight: Weight for text embedding (default 0.4)
            batch_size: Batch size for encoding
            normalize: L2-normalise each output vector (default True)

        Returns:
            2-D numpy array of shape ``(N, embedding_dim)``
        """
        if len(images) != len(texts):
            raise ValueError("Number of images must match number of texts")
            
        # Get batch embeddings (both already normalized if normalize=True)
        image_embs = self.encode_batch_images(images, batch_size=batch_size, normalize=False)
        text_embs = self.encode_batch_texts(texts, batch_size=batch_size, normalize=False)
        
        # Combine with weights
        combined = image_weight * image_embs + text_weight * text_embs
        
        if normalize:
            combined = combined / np.linalg.norm(combined, axis=-1, keepdims=True)
            
        return combined


# ---------------------------------------------------------------------------
# Singleton
# ---------------------------------------------------------------------------

_fashionclip_instance: Optional[FashionCLIPModel] = None


def get_fashionclip_model(
    model_name: str = FASHIONCLIP_MODEL_NAME,
    device: Optional[str] = None,
) -> FashionCLIPModel:
    """Return a singleton FashionCLIPModel instance.

    Args:
        model_name: Hugging Face model name.
        device: Device to run on.

    Returns:
        FashionCLIPModel instance (loaded once, reused thereafter).
    """
    global _fashionclip_instance

    if _fashionclip_instance is None:
        _fashionclip_instance = FashionCLIPModel(model_name, device)

    return _fashionclip_instance

# Export canonical model name for imports
FASHIONCLIP_MODEL = FASHIONCLIP_MODEL_NAME
function digest = sha256Bytes(bytes)
%仅对原始字节计算摘要，避免字符编码改变输入
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(uint8(bytes(:)),'int8'));
digest = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

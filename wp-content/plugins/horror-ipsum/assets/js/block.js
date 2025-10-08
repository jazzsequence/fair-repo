const { registerBlockType } = wp.blocks;
const { RichText } = wp.blockEditor;

const horrorTexts = horrorLipsumData.texts;

registerBlockType('horror-ipsum/random-paragraph', {
    title: 'Horror Ipsum',
    icon: 'admin-comments',
    category: 'widgets',
    attributes: {
        content: {
            type: 'string',
            source: 'html',
            selector: 'p',
        },
    },
    edit: (props) => {
        const { attributes: { content }, setAttributes, clientId } = props;

        // Generate the random paragraph when the block is first created
        if (!content) {
            let randomParagraph = '';
            for (let i = 0; i < 4; i++) {
                const randomIndex = Math.floor(Math.random() * horrorTexts.length);
                randomParagraph += horrorTexts[randomIndex] + ' ';
            }
            setAttributes({ content: randomParagraph.trim() });

            // Automatically replace this block with a core paragraph block
            const { dispatch, select } = wp.data;
            const block = wp.blocks.createBlock('core/paragraph', { content: randomParagraph.trim() });

            dispatch('core/block-editor').replaceBlock(clientId, block);

            // Delay to ensure the block is replaced before selecting the new one
            setTimeout(() => {
                const newBlockId = select('core/block-editor').getBlocks().find(b => b.attributes.content === randomParagraph.trim()).clientId;
                dispatch('core/block-editor').selectBlock(newBlockId);
            }, 50);
        }

        return wp.element.createElement(
            RichText,
            {
                tagName: 'p',
                value: content,
                onChange: (newContent) => setAttributes({ content: newContent }),
                placeholder: 'Horror Ipsum content...',
            }
        );
    },
    save: (props) => {
        return wp.element.createElement(RichText.Content, {
            tagName: 'p',
            value: props.attributes.content,
        });
    },
});
